import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/models.dart';
import '../../source/remote/models/inventory_quantity.dart';
import '../../source/remote/models/stock.dart';
import 'business_context.dart';
import 'warehouse_management.dart';

class StockCommand {
  final String key, action, _body, _before;
  bool attempted;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  StockBalance get before => StockBalance(jsonDecode(_before));
  StockCommand(this.action, Map<String, dynamic> body, StockBalance before)
    : key = const Uuid().v4(),
      _body = jsonEncode(body),
      _before = jsonEncode(before.json),
      attempted = false;
  StockCommand.fromJson(Object? value) : this._(RemoteJson(value));
  StockCommand._(RemoteJson row)
    : key = row.text('key'),
      action = row.text('action'),
      _body = jsonEncode(RemoteJson(row.value['body']).value),
      _before = jsonEncode(RemoteJson(row.value['before']).value),
      attempted = row.flag('attempted') {
    if (!Uuid.isValidUUID(fromString: key) ||
        !['adjust', 'condition', 'transfer'].contains(action)) {
      throw const FormatException('Invalid saved stock command');
    }
    before;
  }
  Map<String, Object> toJson() => {
    'key': key,
    'action': action,
    'body': body,
    'before': before.json,
    'attempted': attempted,
  };
}

class StockFX {
  final BusinessContext context;
  final String warehouseId, branchId;
  final FlutterSecureStorage storage;
  StockCommand? pending;
  bool _sending = false;
  StockFX(
    this.context,
    this.warehouseId, {
    this.storage = const FlutterSecureStorage(),
  }) : branchId = context.selectedBranch?.branchId ?? '';
  int get businessId => context.session.business.businessId;
  String get base => '/v1/businesses/$businessId';
  String get _key =>
      'stock.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId.$warehouseId';
  static const permissions = {
    'READ_STOCK': 'inventory.stock.read',
    'READ_KARDEX': 'inventory.kardex.read',
    'COUNT_STOCK': 'inventory.stock.count',
    'TRANSFER_OUT': 'inventory.stock.transfer',
    'TRANSFER_IN': 'inventory.stock.transfer',
    'ADJUST_STOCK': 'inventory.stock.adjust',
    'MANAGE_CONDITION': 'inventory.stock.condition',
    'RECEIVE_STOCK': 'inventory.stock.receive',
    'ISSUE_STOCK': 'inventory.stock.issue',
  };
  void check() {
    context.check();
    if (branchId.isEmpty ||
        context.selectedBranch?.branchId != branchId ||
        !Uuid.isValidUUID(fromString: warehouseId)) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<Object?> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? data,
    String? key,
  }) async {
    check();
    final result = await context.auth.request(
      method,
      path,
      branchId: branchId,
      query: query,
      data: data,
      idempotencyKey: key,
    );
    check();
    return result;
  }

  Future<bool> allowed(
    String operation, {
    String? warehouse,
    String? branch,
  }) async {
    try {
      final row = RemoteJson(
        await request(
          'POST',
          '$base/inventory-access/check',
          data: {
            'branchId': branch ?? branchId,
            'warehouseId': warehouse ?? warehouseId,
            'operation': operation,
          },
        ),
      );
      if (!row.flag('allowed') ||
          row.text('branchId') != (branch ?? branchId) ||
          row.text('warehouseId') != (warehouse ?? warehouseId) ||
          row.text('permissionCode') != permissions[operation]) {
        throw const FormatException('Invalid stock authorization');
      }
      return true;
    } on AuthError catch (error) {
      if (error.statusCode == 403 && error.code == 'FORBIDDEN' ||
          error.code == 'SCOPE_UNAVAILABLE') {
        return false;
      }
      rethrow;
    }
  }

  Future<void> require(
    String operation, {
    String? warehouse,
    String? branch,
  }) async {
    if (!await allowed(operation, warehouse: warehouse, branch: branch)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
  }

  StockBalance parse(Object? value) {
    final row = StockBalance(value);
    if (row.json['businessId'] != businessId ||
        row.json['warehouseId'] != warehouseId) {
      throw const FormatException('Unexpected stock scope');
    }
    return row;
  }

  Future<({List<StockBalance> items, bool blocked})> balances() async {
    await require('READ_STOCK');
    final rows = <StockBalance>[], ids = <String>{}, cursors = <String>{};
    String? after;
    bool? blocked;
    do {
      final page = RemoteJson(
        await request(
          'GET',
          '$base/inventory/stock',
          query: {'warehouseId': warehouseId, 'limit': '100', 'after': ?after},
        ),
      );
      final lock = page.flag('blockedForCount');
      if (page.number('businessId') != businessId ||
          page.text('warehouseId') != warehouseId ||
          blocked != null && blocked != lock) {
        throw const FormatException('Stock scope or lock changed; reload');
      }
      blocked = lock;
      for (final row in page.items('items', parse)) {
        if (!ids.add(row.id)) throw const FormatException('Repeated balance');
        rows.add(row);
      }
      after = page.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Repeated stock cursor');
      }
    } while (after != null);
    return (items: rows, blocked: blocked);
  }

  Future<List<BusinessBranch>> branches() async {
    final rows = <BusinessBranch>[], ids = <String>{};
    String? after;
    final cursors = <String>{};
    do {
      final page = RemoteJson(
        await request(
          'GET',
          '$base/branches',
          query: {'limit': '100', 'after': ?after},
        ),
      );
      for (final row in page.items('items', BusinessBranch.fromJson)) {
        if (row.businessId != businessId || !ids.add(row.branchId)) {
          throw const FormatException('Unexpected transfer branch');
        }
        if (row.status == 'ACTIVE') rows.add(row);
      }
      after = page.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Invalid branch cursor');
      }
    } while (after != null);
    return rows;
  }

  Future<List<BusinessWarehouse>> destinations(String targetBranch) async {
    final rows = await WarehouseManagementFX.forContext(context).warehouses();
    final allowedRows = <BusinessWarehouse>[];
    for (final row in rows) {
      if (row.status == 'ACTIVE' &&
          row.warehouseId != warehouseId &&
          await allowed(
            'TRANSFER_IN',
            branch: targetBranch,
            warehouse: row.warehouseId,
          )) {
        allowedRows.add(row);
      }
    }
    return allowedRows;
  }

  Future<({List<StockMovement> items, Map<String, dynamic> closing})> kardex(
    StockBalance balance,
  ) async {
    await require('READ_KARDEX');
    int? through, after;
    final rows = <StockMovement>[], ids = <String>{};
    Map<String, dynamic>? closing;
    do {
      final page = RemoteJson(
        await request(
          'GET',
          '$base/inventory/kardex',
          query: {
            'warehouseId': warehouseId,
            'variantId': balance.variantId,
            'limit': '100',
            if (through != null) 'throughSequence': '$through',
            if (after != null) 'afterSequence': '$after',
          },
        ),
      );
      final snapshot = page.number('throughSequence');
      if (page.number('businessId') != businessId ||
          page.text('warehouseId') != warehouseId ||
          page.text('variantId') != balance.variantId ||
          snapshot < 0 ||
          through != null && snapshot != through) {
        throw const FormatException('Unexpected kardex snapshot');
      }
      through = snapshot;
      final end = RemoteJson(page.value['closing']);
      for (final key in StockBalance.buckets) {
        InventoryQuantity.fromJson(end.value[key]);
      }
      if (closing != null && jsonEncode(closing) != jsonEncode(end.value)) {
        throw const FormatException('Kardex snapshot changed');
      }
      closing = end.value;
      for (final row in page.items('items', StockMovement.new)) {
        if (row.json['businessId'] != businessId ||
            row.json['warehouseId'] != warehouseId ||
            row.json['variantId'] != balance.variantId ||
            !ids.add(row.id) ||
            row.sequence <= (rows.isEmpty ? after ?? 0 : rows.last.sequence) ||
            row.sequence > through) {
          throw const FormatException('Unexpected movement');
        }
        rows.add(row);
      }
      final next = page.optionalNumber('nextSequence');
      if (next != null &&
          (next <= (after ?? 0) ||
              rows.isEmpty ||
              next != rows.last.sequence)) {
        throw const FormatException('Invalid kardex cursor');
      }
      after = next;
    } while (after != null);
    return (items: rows, closing: closing);
  }

  Future<StockCommand?> restore() async {
    check();
    if (_sending) return pending;
    final saved = await storage.read(key: _key);
    check();
    final command = saved == null
        ? null
        : StockCommand.fromJson(jsonDecode(saved));
    if (command != null) parse(command.before.json);
    return pending = command;
  }

  Future<void> send(StockCommand command) async {
    if (_sending) throw const AuthError(409, 'STOCK_PENDING');
    _sending = true;
    try {
      if (pending == null) {
        final saved = await storage.read(key: _key);
        check();
        if (saved != null) pending = StockCommand.fromJson(jsonDecode(saved));
      }
      if (pending != null && pending!.key != command.key) {
        throw const AuthError(409, 'STOCK_PENDING');
      }
      final body = RemoteJson(command.body),
          before = parse(command.before.json);
      if (body.text('variantId') != before.variantId ||
          body.text(
                command.action == 'transfer'
                    ? 'fromWarehouseId'
                    : 'warehouseId',
              ) !=
              warehouseId) {
        throw const FormatException('Unexpected stock command');
      }
      if (command.action == 'transfer') {
        await require('TRANSFER_OUT');
        await require(
          'TRANSFER_IN',
          warehouse: body.text('toWarehouseId'),
          branch: body.text('toBranchId'),
        );
      } else {
        await require(
          command.action == 'adjust' ? 'ADJUST_STOCK' : 'MANAGE_CONDITION',
        );
        if (body.number('expectedRevision') != before.revision) {
          throw const FormatException('Invalid stock revision');
        }
        if (command.action == 'adjust') {
          await require(
            body.text('direction') == 'IN' ? 'RECEIVE_STOCK' : 'ISSUE_STOCK',
          );
        }
      }
      final previouslyAttempted = command.attempted;
      pending = command;
      command.attempted = true;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      try {
        final result = RemoteJson(
          await request(
            'POST',
            '$base/inventory/stock/${command.action}',
            data: body.value,
            key: command.key,
          ),
        );
        if (result.number('businessId') != businessId) {
          throw const FormatException('Unexpected stock confirmation');
        }
        if (command.action == 'transfer') {
          final row = RemoteJson(result.value['transfer']);
          if (!Uuid.isValidUUID(fromString: row.text('transferId')) ||
              row.number('businessId') != businessId ||
              row.text('branchId') != branchId ||
              row.number('revision') < 1) {
            throw const FormatException('Invalid transfer confirmation');
          }
          for (final key in [
            'fromWarehouseId',
            'toWarehouseId',
            'toBranchId',
            'variantId',
            'condition',
          ]) {
            if (row.text(key) != body.text(key)) {
              throw const FormatException('Unexpected transfer data');
            }
          }
          if (StockBalance.units(row.text('quantity')) !=
              StockBalance.units(body.text('quantity'))) {
            throw const FormatException('Unexpected transfer quantity');
          }
        } else {
          final row = parse(result.value['balance']);
          if (row.id != before.id ||
              row.variantId != before.variantId ||
              row.productId != before.productId ||
              row.revision <= before.revision) {
            throw const FormatException('Invalid changed balance');
          }
          final amount = StockBalance.units(body.text('quantity'));
          var physical = BigInt.zero, damaged = BigInt.zero;
          if (command.action == 'adjust') {
            physical = body.text('direction') == 'IN' ? amount : -amount;
          } else {
            final action = body.text('action');
            damaged = action == 'QUARANTINE' ? amount : -amount;
            if (action == 'SCRAP') physical = -amount;
          }
          if (StockBalance.units(row.quantity('onHand')) !=
                  StockBalance.units(before.quantity('onHand')) + physical ||
              StockBalance.units(row.quantity('damaged')) !=
                  StockBalance.units(before.quantity('damaged')) + damaged) {
            throw const FormatException('Unexpected stock effect');
          }
        }
        await storage.delete(key: _key);
        pending = null;
      } on AuthError catch (error) {
        if (!previouslyAttempted &&
            error.statusCode < 500 &&
            !error.retryable &&
            !error.requiresLogin &&
            error.statusCode != 403 &&
            ![
              'IDEMPOTENCY_CONFLICT',
              'SELECTION_CHANGED',
            ].contains(error.code)) {
          await storage.delete(key: _key);
          pending = null;
        }
        rethrow;
      }
    } finally {
      _sending = false;
    }
  }

  static String message(Object error) {
    if (error is AuthError) {
      switch (error.code) {
        case 'STOCK_PENDING':
          return 'درخواست قبلی تعیین تکلیف نشده است؛ همان درخواست را پیگیری کنید.';
        case 'INSUFFICIENT_STOCK':
          return 'موجودی مناسب برای این عملیات کافی نیست؛ موجودی را تازه کنید.';
        case 'VALIDATION_FAILED':
          return 'تعداد، نوع عملیات، دلیل و انبار مقصد را بررسی کنید.';
        case 'WAREHOUSE_COUNT_IN_PROGRESS':
          return 'انبار برای انبارگردانی قفل است.';
      }
      if (!error.requiresLogin &&
          error.statusCode < 500 &&
          ![
            'FORBIDDEN',
            'REVISION_CONFLICT',
            'IDEMPOTENCY_CONFLICT',
            'SELECTION_CHANGED',
          ].contains(error.code)) {
        return 'عملیات انبار انجام نشد؛ کد خطای سرور: ${error.code}';
      }
    }
    return WarehouseManagementFX.message(error);
  }
}
