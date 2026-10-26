import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/remote_json.dart';
import '../../source/remote/models/stock_count.dart';
import '../../source/remote/models/stock.dart';
import 'stock.dart';

class StockCountCommand {
  final String action, key, _body;
  final String? _before;
  bool attempted;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  StockCount? get before =>
      _before == null ? null : StockCount(jsonDecode(_before));
  StockCountCommand(
    this.action,
    Map<String, dynamic> body, {
    StockCount? before,
  }) : key = const Uuid().v4(),
       _body = jsonEncode(body),
       _before = before == null ? null : jsonEncode(before.json),
       attempted = false;
  StockCountCommand.fromJson(Object? value) : this._(RemoteJson(value));
  StockCountCommand._(RemoteJson row)
    : action = row.text('action'),
      key = row.text('key'),
      _body = jsonEncode(RemoteJson(row.value['body']).value),
      _before = row.value['before'] == null
          ? null
          : jsonEncode(row.value['before']),
      attempted = row.flag('attempted') {
    if (!['start', 'update', 'post', 'cancel'].contains(action) ||
        !Uuid.isValidUUID(fromString: key)) {
      throw const FormatException('Invalid pending count');
    }
  }
  Map<String, Object?> toJson() => {
    'action': action,
    'key': key,
    'body': body,
    'before': before?.json,
    'attempted': attempted,
  };
}

class StockCountFX {
  final StockFX stock;
  final FlutterSecureStorage storage;
  StockCountCommand? pending;
  bool _sending = false;
  StockCountFX(this.stock, {this.storage = const FlutterSecureStorage()});
  String get _key =>
      'count.v1.${stock.context.auth.appId}.${stock.context.origin}.${stock.context.session.identityId}.${stock.businessId}.${stock.branchId}.${stock.warehouseId}';
  StockCount parse(Object? value) {
    final row = StockCount(value);
    if (row.json['businessId'] != stock.businessId ||
        row.json['branchId'] != stock.branchId ||
        row.json['warehouseId'] != stock.warehouseId) {
      throw const FormatException('Unexpected count scope');
    }
    return row;
  }

  Future<List<StockCount>> all() async {
    await stock.require('COUNT_STOCK');
    final rows = <StockCount>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final page = RemoteJson(
        await stock.request(
          'GET',
          '${stock.base}/inventory/counts',
          query: {
            'warehouseIds': stock.warehouseId,
            'limit': '100',
            'after': ?after,
          },
        ),
      );
      if (page.number('businessId') != stock.businessId) {
        throw const FormatException('Unexpected count list');
      }
      for (final row in page.items('items', parse)) {
        if (!ids.add(row.id)) throw const FormatException('Repeated count');
        rows.add(row);
      }
      after = page.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Invalid count cursor');
      }
    } while (after != null);
    return rows;
  }

  Future<StockCount> get(String id) async {
    await stock.require('COUNT_STOCK');
    final result = RemoteJson(
      await stock.request(
        'GET',
        '${stock.base}/inventory/counts/${Uri.encodeComponent(id)}',
      ),
    );
    final row = parse(result.value['item']);
    if (result.number('businessId') != stock.businessId || row.id != id) {
      throw const FormatException('Unexpected count detail');
    }
    return row;
  }

  void _validate(StockCountCommand command) {
    final body = RemoteJson(command.body);
    if (command.action == 'start') {
      final ids = body.strings('variantIds');
      if (body.text('warehouseId') != stock.warehouseId ||
          ids.isEmpty ||
          ids.length > 30 ||
          ids.toSet().length != ids.length ||
          ids.any((id) => !Uuid.isValidUUID(fromString: id))) {
        throw const FormatException('Invalid count start');
      }
    } else {
      final before = parse(command.before?.json);
      if (before.id != body.text('countId') ||
          before.revision != body.number('expectedRevision') ||
          before.status != 'OPEN') {
        throw const FormatException('Invalid count command');
      }
    }
  }

  Future<StockCountCommand?> restore() async {
    stock.check();
    if (_sending) return pending;
    final value = await storage.read(key: _key);
    stock.check();
    final saved = value == null
        ? null
        : StockCountCommand.fromJson(jsonDecode(value));
    if (saved != null) _validate(saved);
    return pending = saved;
  }

  Future<StockCount> send(StockCountCommand command) async {
    if (_sending) throw const AuthError(409, 'COUNT_PENDING');
    _sending = true;
    try {
      stock.check();
      if (pending == null) {
        final saved = await storage.read(key: _key);
        stock.check();
        if (saved != null) {
          pending = StockCountCommand.fromJson(jsonDecode(saved));
        }
      }
      if (pending != null && pending!.key != command.key) {
        throw const AuthError(409, 'COUNT_PENDING');
      }
      await stock.require('COUNT_STOCK');
      _validate(command);
      final previousAttempt = command.attempted;
      pending = command;
      command.attempted = true;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      try {
        final result = RemoteJson(
          await stock.request(
            'POST',
            '${stock.base}/inventory/counts${command.action == 'start' ? '' : '/${command.action}'}',
            data: command.body,
            key: command.key,
          ),
        );
        if (result.number('businessId') != stock.businessId) {
          throw const FormatException('Unexpected count business');
        }
        final row = parse(result.value['count']),
            body = RemoteJson(command.body);
        final expectedStatus = const {
          'start': 'OPEN',
          'update': 'OPEN',
          'post': 'POSTED',
          'cancel': 'CANCELLED',
        }[command.action];
        if (row.status != expectedStatus) {
          throw const FormatException('Unexpected count state');
        }
        if (command.action == 'start') {
          final ids = body.strings('variantIds');
          if (row.lines.length != ids.length ||
              row.lines.any((l) => !ids.contains(l.id)) ||
              row.json['reason'] != body.text('reason')) {
            throw const FormatException('Unexpected started count');
          }
        } else {
          final before = command.before!;
          if (row.id != before.id ||
              row.revision <= before.revision ||
              row.lines.length != before.lines.length) {
            throw const FormatException('Unexpected updated count');
          }
          final updates = command.action == 'update'
              ? body.items('lines', (v) => RemoteJson(v))
              : <RemoteJson>[];
          for (final old in before.lines) {
            final matching = row.lines.where((l) => l.id == old.id);
            if (matching.length != 1) {
              throw const FormatException('Count line changed');
            }
            final line = matching.single;
            for (final key in [
              'productId',
              'unitId',
              'expectedRevision',
              'onHand',
              'damaged',
              'reserved',
              'allocationPending',
            ]) {
              if (line.json[key] != old.json[key]) {
                throw const FormatException('Count snapshot changed');
              }
            }
            for (final key in ['countedOnHand', 'countedDamaged']) {
              final changes = updates.where(
                (l) => l.text('variantId') == old.id,
              );
              final expected = changes.isEmpty
                  ? old.json[key]
                  : changes.single.value[key];
              if (expected == null
                  ? line.json[key] != null
                  : StockBalance.units(line.amount(key)) !=
                        StockBalance.units(expected as String)) {
                throw const FormatException('Count values differ');
              }
            }
          }
          if (command.action == 'post' && row.lines.any((l) => !l.counted)) {
            throw const FormatException('Uncounted posted line');
          }
        }
        await storage.delete(key: _key);
        pending = null;
        return row;
      } on AuthError catch (error) {
        // An unknown result retains its exact body and key, including later conflicts.
        if (!previousAttempt &&
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
        case 'COUNT_PENDING':
          return 'نتیجه درخواست قبلی انبارگردانی مشخص نیست؛ همان درخواست را پیگیری کنید.';
        case 'HELD_STOCK_CONFLICT':
          return 'موجودی شمارش‌شده از مجموع آسیب‌دیده، رزرو و در انتظار تخصیص کمتر است. شمارش را لغو و رزروها را تعیین تکلیف کنید؛ سپس دوباره بشمارید.';
        case 'REVISION_CONFLICT':
          return 'نسخه شمارش یا موجودی تغییر کرده است؛ اطلاعات تازه را دریافت کنید. اگر موجودی مبنا تغییر کرده، شمارش را لغو و دوباره آغاز کنید.';
        case 'INVALID_STATE':
          return 'این شمارش دیگر باز نیست؛ اطلاعات تازه را دریافت کنید.';
      }
    }
    return StockFX.message(error);
  }
}
