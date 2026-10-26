import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/models.dart';
import 'business_context.dart';

enum WarehouseAction { create, rename, link, defaultWarehouse }

class WarehouseCommand {
  final WarehouseAction action;
  final String key, _body;
  final String? id;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  WarehouseCommand(this.action, Map<String, dynamic> body, {this.id})
    : key = const Uuid().v4(),
      _body = jsonEncode(body);
  WarehouseCommand.fromJson(Object? value) : this._(RemoteJson(value));
  WarehouseCommand._(RemoteJson json)
    : action = WarehouseAction.values.byName(json.text('action')),
      key = json.text('key'),
      id = json.optionalText('id'),
      _body = jsonEncode(RemoteJson(json.value['body']).value) {
    if (!Uuid.isValidUUID(fromString: key) ||
        id != null && !Uuid.isValidUUID(fromString: id!)) {
      throw const FormatException('Invalid warehouse command');
    }
  }
  Map<String, Object?> toJson() => {
    'action': action.name,
    'key': key,
    'id': id,
    'body': body,
  };
}

class WarehouseManagementFX {
  static final _contexts = Expando<Map<String, WarehouseManagementFX>>();
  static WarehouseManagementFX forContext(
    BusinessContext context, {
    String? branchId,
  }) {
    final clients = _contexts[context] ??= {};
    final target = branchId ?? context.selectedBranch?.branchId;
    final cacheKey = '${context.selectedBranch?.branchId}:$target';
    return clients[cacheKey] ??= WarehouseManagementFX(
      context: context,
      branchId: target,
    );
  }

  final BusinessContext context;
  final FlutterSecureStorage storage;
  final String? branchId, _selectedBranchId;
  final accessVersion = 0.obs;
  final _grants = <String, ScopeAuthorization>{};
  WarehouseCommand? pending;
  Future<Object>? _sending;
  WarehouseManagementFX({
    required this.context,
    this.storage = const FlutterSecureStorage(),
    String? branchId,
  }) : branchId = branchId ?? context.selectedBranch?.branchId,
       _selectedBranchId = context.selectedBranch?.branchId;
  int get businessId => context.session.business.businessId;
  bool get owner => context.session.business.membershipType == 'OWNER';
  String get _base => '/v1/businesses/$businessId';
  String get _key =>
      'warehouses.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId';
  void check() {
    context.check();
    if (!identical(BusinessContext.forApp(context.auth.appId), context) ||
        context.selectedBranch?.branchId != _selectedBranchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  bool has(String code, {String scope = 'BUSINESS', String? id}) {
    accessVersion.value;
    return context.valid &&
        context.selectedBranch?.branchId == _selectedBranchId &&
        _grants['$scope:${id ?? businessId}']?.permissionCodes.contains(code) ==
            true;
  }

  Future<void> authorize({String scope = 'BUSINESS', String? id}) async {
    check();
    final scopeId = id ?? '$businessId';
    final key = '$scope:$scopeId';
    _grants.remove(key);
    accessVersion.value++;
    final result = ScopeAuthorization.fromJson(
      await context.auth.request(
        'GET',
        '$_base/authorization',
        query: {'scopeType': scope, 'scopeId': scopeId},
      ),
    );
    check();
    if (!result.allowed ||
        result.businessId != businessId ||
        result.membershipId != context.session.business.membershipId ||
        result.scopeType != scope ||
        result.scopeId != scopeId) {
      throw const FormatException('Unexpected warehouse authorization');
    }
    _grants[key] = result;
    accessVersion.value++;
  }

  bool canRename(String id) => owner
      ? has('business.warehouse.update')
      : has('business.warehouse.update', scope: 'WAREHOUSE', id: id);
  bool get canDefault =>
      branchId != null &&
      (owner
          ? has('business.branch.update')
          : has('business.branch.update', scope: 'BRANCH', id: branchId));
  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? key,
  }) async {
    check();
    try {
      // Managing another branch must not change the branch used by invoices.
      final result = branchId == _selectedBranchId
          ? await context.request(
              method,
              path,
              query: query,
              data: body,
              idempotencyKey: key,
            )
          : await context.auth.request(
              method,
              path,
              branchId: branchId,
              query: query,
              data: body,
              idempotencyKey: key,
            );
      check();
      return result;
    } on AuthError catch (failure) {
      if (failure.statusCode == 403 || failure.requiresLogin) {
        _grants.clear();
        accessVersion.value++;
      }
      rethrow;
    }
  }

  void _record(int business, String id, String status, int revision) {
    if (business != businessId ||
        !Uuid.isValidUUID(fromString: id) ||
        revision < 1 ||
        !['ACTIVE', 'SUSPENDED', 'ARCHIVED'].contains(status)) {
      throw const FormatException('Unexpected warehouse record');
    }
  }

  BusinessWarehouse _warehouse(Object? value) {
    final row = BusinessWarehouse.fromJson(value);
    _record(row.businessId, row.warehouseId, row.status, row.revision);
    return row;
  }

  BranchAccess _link(Object? value) {
    final row = BranchAccess.fromJson(value);
    _record(row.businessId, row.branchAccessId, row.status, row.revision);
    if (row.branchId != branchId ||
        !Uuid.isValidUUID(fromString: row.warehouseId)) {
      throw const FormatException('Unexpected branch warehouse link');
    }
    return row;
  }

  Future<List<T>> _pages<T>(
    String path,
    T Function(Object?) parse,
    String Function(T) id, {
    Map<String, String> filters = const {},
  }) async {
    final rows = <T>[], cursors = <String>{}, ids = <String>{};
    String? cursor;
    do {
      final page = RemoteJson(
        await _request(
          'GET',
          '$_base/$path',
          query: {'limit': '100', 'after': ?cursor, ...filters},
        ),
      );
      final items = page.items('items', parse);
      if (items.any((row) => !ids.add(id(row)))) {
        throw const FormatException('Repeated warehouse record');
      }
      rows.addAll(items);
      cursor = page.optionalText('nextCursor');
      if (cursor != null && !cursors.add(cursor)) {
        throw const FormatException('Repeated warehouse cursor');
      }
    } while (cursor != null);
    return rows;
  }

  Future<List<BusinessWarehouse>> warehouses() =>
      _pages('warehouses', _warehouse, (row) => row.warehouseId);
  Future<List<BranchAccess>> links() async {
    if (branchId == null || !has('business.branch-access.read')) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    return _pages(
      'branch-access',
      _link,
      (row) => row.branchAccessId,
      filters: {'branchId': branchId!},
    );
  }

  Future<bool> canReceive(String warehouseId) async {
    check();
    if (branchId == null || !Uuid.isValidUUID(fromString: warehouseId)) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
    try {
      // A denied candidate is normal filtering; it must not clear the selected branch.
      final result = RemoteJson(
        await context.auth.request(
          'POST',
          '$_base/inventory-access/check',
          branchId: branchId,
          data: {
            'branchId': branchId,
            'warehouseId': warehouseId,
            'operation': 'RECEIVE_STOCK',
          },
        ),
      );
      check();
      if (!result.flag('allowed') ||
          result.text('branchId') != branchId ||
          result.text('warehouseId') != warehouseId ||
          result.text('permissionCode') != 'inventory.stock.receive') {
        throw const FormatException('Unexpected inventory access response');
      }
      return true;
    } on AuthError catch (failure) {
      check();
      if (failure.code == 'FORBIDDEN' && failure.statusCode == 403 ||
          failure.code == 'SCOPE_UNAVAILABLE') {
        return false;
      }
      rethrow;
    }
  }

  Future<BusinessBranch> branch() async {
    if (branchId == null) throw const AuthError(409, 'SELECTION_CHANGED');
    final json = RemoteJson(await _request('GET', '$_base/branches/$branchId'));
    final row = BusinessBranch.fromJson(json.value['item']);
    _record(row.businessId, row.branchId, row.status, row.revision);
    if (row.branchId != branchId) {
      throw const FormatException('Unexpected branch');
    }
    if (row.status == 'ACTIVE' && row.branchId == _selectedBranchId) {
      context.updateSelectedBranch(row);
    }
    return row;
  }

  Future<WarehouseCommand?> restore() async {
    if (_sending != null) return pending;
    check();
    final saved = await storage.read(key: _key);
    check();
    return pending = saved == null
        ? null
        : WarehouseCommand.fromJson(jsonDecode(saved));
  }

  Future<Object> send(WarehouseCommand command) {
    if (_sending != null) {
      if (pending?.key != command.key) {
        return Future.error(const AuthError(409, 'WAREHOUSE_PENDING'));
      }
      return _sending!;
    }
    final result = _send(command);
    _sending = result;
    return result.whenComplete(() => _sending = null);
  }

  Future<Object> _send(WarehouseCommand command) async {
    check();
    if (pending != null && pending!.key != command.key) {
      throw const AuthError(409, 'WAREHOUSE_PENDING');
    }
    await authorize();
    if (command.action == WarehouseAction.rename && !owner) {
      await authorize(scope: 'WAREHOUSE', id: command.id);
    }
    if (command.action == WarehouseAction.defaultWarehouse && !owner) {
      await authorize(scope: 'BRANCH', id: branchId);
    }
    final allowed = switch (command.action) {
      WarehouseAction.create => has('business.warehouse.create'),
      WarehouseAction.rename => command.id != null && canRename(command.id!),
      WarehouseAction.link => has('business.branch-access.update'),
      WarehouseAction.defaultWarehouse => command.id == branchId && canDefault,
    };
    if (!allowed) throw const AuthError(403, 'FORBIDDEN');
    final path = switch (command.action) {
      WarehouseAction.create => 'warehouses',
      WarehouseAction.rename => 'warehouses/${command.id}',
      WarehouseAction.link =>
        command.id == null ? 'branch-access' : 'branch-access/${command.id}',
      WarehouseAction.defaultWarehouse => 'branches/${command.id}',
    };
    pending = command;
    await storage.write(key: _key, value: jsonEncode(command.toJson()));
    try {
      final updating =
          command.action != WarehouseAction.create &&
          (command.action != WarehouseAction.link || command.id != null);
      final json = RemoteJson(
        await _request(
          updating ? 'PATCH' : 'POST',
          '$_base/$path',
          body: command.body,
          key: command.key,
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected warehouse business');
      }
      final Object result;
      switch (command.action) {
        case WarehouseAction.create:
        case WarehouseAction.rename:
          final row = _warehouse(json.value['item']);
          if (command.id != null &&
                  (row.warehouseId != command.id ||
                      row.revision <= command.body['expectedRevision']) ||
              row.name != command.body['name'] ||
              command.body.containsKey('status') &&
                  row.status != command.body['status']) {
            throw const FormatException('Unexpected saved warehouse');
          }
          result = row;
        case WarehouseAction.link:
          final row = _link(json.value['item']);
          if (command.id != null && row.branchAccessId != command.id ||
              command.id == null &&
                  row.warehouseId != command.body['warehouseId']) {
            throw const FormatException('Unexpected saved warehouse link');
          }
          if (row.status != command.body['status'] ||
              row.canReadStock != command.body['canReadStock'] ||
              row.canReceiveStock != command.body['canReceiveStock'] ||
              row.canIssueStock != command.body['canIssueStock'] ||
              command.id != null &&
                  row.revision <= command.body['expectedRevision']) {
            throw const FormatException(
              'Unexpected saved warehouse permissions',
            );
          }
          result = row;
        case WarehouseAction.defaultWarehouse:
          final row = BusinessBranch.fromJson(json.value['item']);
          _record(row.businessId, row.branchId, row.status, row.revision);
          if (row.branchId != branchId ||
              row.revision <= command.body['expectedRevision'] ||
              row.defaultWarehouseId != command.body['defaultWarehouseId']) {
            throw const FormatException('Unexpected saved default warehouse');
          }
          if (row.branchId == _selectedBranchId) {
            context.updateSelectedBranch(row);
          }
          result = row;
      }
      await storage.delete(key: _key);
      pending = null;
      return result;
    } on AuthError catch (failure) {
      if (failure.statusCode < 500 &&
          !failure.retryable &&
          !failure.requiresLogin &&
          failure.statusCode != 403 &&
          ![
            'IDEMPOTENCY_CONFLICT',
            'SELECTION_CHANGED',
          ].contains(failure.code)) {
        await storage.delete(key: _key);
        pending = null;
      }
      rethrow;
    }
  }

  static String message(Object failure) {
    if (failure is AuthError) {
      switch (failure.code) {
        case 'FORBIDDEN':
          return 'مجوز این عملیات یا دسترسی به انبار را ندارید.';
        case 'REVISION_CONFLICT':
          return 'اطلاعات تغییر کرده است؛ نسخه جدید را دریافت کنید.';
        case 'DEFAULT_WAREHOUSE_UNAVAILABLE':
          return 'انبار پیش‌فرض باید فعال و برای مشاهده و خروج کالا به شعبه متصل باشد. ابتدا انبار پیش‌فرض دیگری انتخاب کنید.';
        case 'DUPLICATE_RECORD':
          return 'این انبار یا ارتباط شعبه قبلاً ثبت شده است.';
        case 'WAREHOUSE_PENDING':
        case 'IDEMPOTENCY_CONFLICT':
          return 'درخواست قبلی تعیین تکلیف نشده؛ همان درخواست را ادامه دهید.';
        case 'VALIDATION_FAILED':
          return 'نام انبار و ارتباط شعبه را بررسی کنید.';
        case 'SELECTION_CHANGED':
          return 'نشست یا شعبه تغییر کرده؛ صفحه را دوباره باز کنید.';
      }
    }
    if (failure is FormatException) {
      return 'پاسخ سرور کامل نیست؛ دوباره تلاش کنید.';
    }
    return API.loginError(failure);
  }
}
