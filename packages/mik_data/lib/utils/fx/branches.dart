import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/api.dart';
import '../../source/remote/models/models.dart';
import '../../source/remote/models/branch_fund.dart';
import 'business_context.dart';
import 'warehouse_management.dart';

class BranchCommand {
  final String key, _body;
  final String? id;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  BranchCommand(Map<String, dynamic> body, {this.id})
    : key = const Uuid().v4(),
      _body = jsonEncode(body);
  BranchCommand.fromJson(Object? value) : this._(RemoteJson(value));
  BranchCommand._(RemoteJson json)
    : key = json.text('key'),
      id = json.optionalText('id'),
      _body = jsonEncode(RemoteJson(json.value['body']).value) {
    if (!Uuid.isValidUUID(fromString: key) ||
        id != null && !Uuid.isValidUUID(fromString: id!)) {
      throw const FormatException('Invalid branch command');
    }
  }
  Map<String, Object?> toJson() => {'key': key, 'id': id, 'body': body};
}

class BranchesFX {
  static final _contexts = Expando<BranchesFX>();
  static BranchesFX forContext(BusinessContext context) =>
      _contexts[context] ??= BranchesFX(context);
  final BusinessContext context;
  final FlutterSecureStorage storage;
  late final access = WarehouseManagementFX(context: context);
  BranchCommand? pending;
  Future<BusinessBranch>? _sending;
  BranchesFX(this.context, {this.storage = const FlutterSecureStorage()});
  int get businessId => context.session.business.businessId;
  String get _base => '/v1/businesses/$businessId/branches';
  String get _key =>
      'branches.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId';
  void check() {
    context.check();
    if (!identical(context, BusinessContext.forApp(context.auth.appId))) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<void> authorize({String? id}) async {
    check();
    await access.authorize();
    if (id != null && !access.owner) {
      await access.authorize(scope: 'BRANCH', id: id);
    }
    check();
  }

  bool get canCreate => access.has('business.branch.create');
  bool canEdit(String id) => access.owner
      ? access.has('business.branch.update')
      : access.has('business.branch.update', scope: 'BRANCH', id: id);
  BusinessBranch _parse(Object? value) {
    final row = BusinessBranch.fromJson(value);
    if (row.businessId != businessId ||
        !Uuid.isValidUUID(fromString: row.branchId) ||
        row.revision < 1 ||
        !['ACTIVE', 'SUSPENDED', 'ARCHIVED'].contains(row.status) ||
        row.defaultWarehouseId != null &&
            !Uuid.isValidUUID(fromString: row.defaultWarehouseId!) ||
        row.address?['fullAddress'] != null &&
            row.address!['fullAddress'] is! String) {
      throw const FormatException('Unexpected branch record');
    }
    return row;
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? data,
    String? key,
  }) async {
    check();
    final result = await context.request(
      method,
      path,
      query: query,
      data: data,
      idempotencyKey: key,
    );
    check();
    return result;
  }

  Future<List<BusinessBranch>> all() async {
    final result = <BusinessBranch>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await _request('GET', _base, query: {'limit': '100', 'after': ?after}),
      );
      final rows = json.items('items', _parse);
      if (rows.any((b) => !ids.add(b.branchId))) {
        throw const FormatException('Repeated branch');
      }
      result.addAll(rows);
      after = json.optionalText('nextCursor');
      if (after != null && !cursors.add(after)) {
        throw const FormatException('Repeated branch cursor');
      }
    } while (after != null);
    return result;
  }

  Future<BusinessBranch> get(String id) async {
    final row = _parse(
      RemoteJson(await _request('GET', '$_base/${Uri.encodeComponent(id)}'))
          .value['item'],
    );
    if (row.branchId != id) throw const FormatException('Unexpected branch id');
    return row;
  }

  Future<List<BranchFund>> funds(String id) async {
    check();
    final selected = context.selectedBranch?.branchId;
    void validateScope() {
      check();
      if (context.selectedBranch?.branchId != selected) {
        throw const AuthError(409, 'SELECTION_CHANGED');
      }
    }

    await access.authorize(scope: 'BRANCH', id: id);
    if (!access.has('accounting.treasury.read', scope: 'BRANCH', id: id)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final rows = <BranchFund>[], ids = <String>{};
    for (final kind in ['CASH', 'PETTY_CASH']) {
      final cursors = <String>{};
      String? after;
      do {
        // Reading another branch must not change the branch used by invoices.
        validateScope();
        final json = RemoteJson(
          await context.auth.request(
            'GET',
            '/v1/businesses/$businessId/accounting/treasury/funds',
            branchId: id,
            query: {'kind': kind, 'limit': '100', 'after': ?after},
          ),
        );
        validateScope();
        final items = json.items('items', BranchFund.fromJson);
        if (json.number('businessId') != businessId ||
            items.any(
              (r) =>
                  r.businessId != businessId ||
                  r.branchId != id ||
                  r.kind != kind ||
                  !ids.add(r.id),
            )) {
          throw const FormatException('Unexpected branch funds scope');
        }
        rows.addAll(items);
        after = json.optionalText('nextCursor');
        if (after != null &&
            (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
          throw const FormatException('Repeated branch fund cursor');
        }
      } while (after != null);
    }
    return rows;
  }

  Future<BranchCommand?> restore() async {
    check();
    if (_sending != null) return pending;
    final value = await storage.read(key: _key);
    check();
    return pending = value == null
        ? null
        : BranchCommand.fromJson(jsonDecode(value));
  }

  Future<BusinessBranch> send(BranchCommand command) {
    if (_sending != null) {
      if (pending?.key != command.key) {
        return Future.error(const AuthError(409, 'IDEMPOTENCY_CONFLICT'));
      }
      return _sending!;
    }
    final result = _send(command);
    _sending = result;
    return result.whenComplete(() => _sending = null);
  }

  Future<BusinessBranch> _send(BranchCommand command) async {
    if (pending != null && pending!.key != command.key) {
      throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    }
    await authorize(id: command.id);
    if (command.id == null ? !canCreate : !canEdit(command.id!)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    pending = command;
    await storage.write(key: _key, value: jsonEncode(command.toJson()));
    try {
      final json = RemoteJson(
        await _request(
          command.id == null ? 'POST' : 'PATCH',
          command.id == null ? _base : '$_base/${command.id}',
          data: command.body,
          key: command.key,
        ),
      );
      final row = _parse(json.value['item']);
      if (json.number('businessId') != businessId ||
          command.id != null && row.branchId != command.id ||
          row.name != command.body['name']) {
        throw const FormatException('Unexpected saved branch');
      }
      if (context.selectedBranch?.branchId == row.branchId &&
          row.status == 'ACTIVE') {
        context.updateSelectedBranch(row);
      }
      await storage.delete(key: _key);
      pending = null;
      return row;
    } on AuthError catch (error) {
      if (error.statusCode < 500 &&
          !error.retryable &&
          !error.requiresLogin &&
          error.statusCode != 403 &&
          !['IDEMPOTENCY_CONFLICT', 'SELECTION_CHANGED'].contains(error.code)) {
        await storage.delete(key: _key);
        pending = null;
      }
      rethrow;
    }
  }

  static String message(Object failure) {
    if (failure is FormatException) {
      return 'پاسخ شعبه معتبر نیست؛ نتیجه درخواست قبلی را پیگیری کنید.';
    }
    if (failure is AuthError) {
      if (failure.code == 'FORBIDDEN') {
        return 'مجوز مشاهده یا تغییر شعبه را ندارید.';
      }
      if (failure.code == 'REVISION_CONFLICT') {
        return 'شعبه تغییر کرده است؛ اطلاعات جدید را دریافت و دوباره ویرایش کنید.';
      }
      if (failure.code == 'IDEMPOTENCY_CONFLICT') {
        return 'درخواست قبلی تعیین تکلیف نشده است؛ همان درخواست را ادامه دهید.';
      }
      if (failure.code == 'SELECTION_CHANGED') {
        return 'نشست یا شعبه انتخاب‌شده تغییر کرده است؛ صفحه را دوباره باز کنید.';
      }
      if (!failure.requiresLogin && failure.statusCode < 500) {
        return 'عملیات شعبه انجام نشد؛ کد خطای سرور: ${failure.code}';
      }
    }
    return API.loginError(failure);
  }
}
