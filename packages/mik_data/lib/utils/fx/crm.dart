import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/crm.dart';
import '../../source/remote/models/customer.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';
import 'customers.dart';

class CrmFX {
  static final _clients = Expando<Map<String, CrmFX>>();
  static CrmFX forContext(BusinessContext context) =>
      (_clients[context] ??= {})[context.selectedBranch?.branchId ?? ''] ??=
          CrmFX(context);
  final BusinessContext context;
  final FlutterSecureStorage storage;
  late final customers = CustomersFX(context: context);
  CrmCommand? pending;
  Future<CrmEntry>? _sending;
  String? _sendingKey;
  CrmFX(this.context, {this.storage = const FlutterSecureStorage()});
  int get businessId => context.session.business.businessId;
  String get base => '/v1/businesses/$businessId';
  String get _key =>
      'crm.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.${customers.branchId}';
  bool has(String code) => customers.has(code);
  bool canRead(CrmKind type) =>
      has('${type.permission}.read') || has('${type.permission}.read.all');
  bool canEdit(CrmEntry row) =>
      has('${row.type.permission}.update') &&
      (row.creator == context.session.identityId ||
          has('${row.type.permission}.update.all') ||
          row.type == CrmKind.followup &&
              row.data['responsibleMembershipId'] ==
                  context.session.business.membershipId);
  Future<void> authorize() => customers.authorize();
  Future<Object?> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? key,
  }) async {
    customers.check();
    final value = await context.request(
      method,
      path,
      query: query,
      data: body,
      idempotencyKey: key,
    );
    customers.check();
    return value;
  }

  Future<List<RemoteCustomer>> customerList() async {
    if (!customers.canRead) throw const AuthError(403, 'FORBIDDEN');
    final rows = <RemoteCustomer>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await request(
          'GET',
          '$base/customers',
          query: {'status': 'ALL', 'limit': '100', 'after': ?after},
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected customer business');
      }
      final items = json.items('items', RemoteCustomer.fromJson);
      if (items.any(
        (row) => row.businessId != businessId || !ids.add(row.id),
      )) {
        throw const FormatException('Unexpected CRM customer');
      }
      rows.addAll(items);
      after = json.optionalText('nextCursor');
      if (after != null && !cursors.add(after)) {
        throw const FormatException('Repeated CRM cursor');
      }
    } while (after != null);
    return rows;
  }

  CrmEntry _parse(Object? value, CrmKind type) {
    final row = CrmEntry(value, type);
    if (row.businessId != businessId) {
      throw const FormatException('Unexpected CRM business');
    }
    return row;
  }

  Future<List<CrmEntry>> list(
    CrmKind type, {
    String? customerId,
    String? status,
  }) async {
    customers.check();
    if (!canRead(type)) throw const AuthError(403, 'FORBIDDEN');
    if (type == CrmKind.interaction && customerId == null) {
      throw const AuthError(400, 'CUSTOMER_REQUIRED');
    }
    final rows = <CrmEntry>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await request(
          'GET',
          '$base/${type.path}',
          query: {
            'limit': '100',
            'customerId': ?customerId,
            'status': ?status,
            'after': ?after,
          },
        ),
      );
      final items = json.items('items', (value) => _parse(value, type));
      if (json.number('businessId') != businessId ||
          items.any(
            (row) =>
                !ids.add(row.id) ||
                customerId != null && row.customerId != customerId ||
                status != null && row.status != status,
          )) {
        throw const FormatException('Unexpected CRM page');
      }
      rows.addAll(items);
      after = json.optionalText('nextCursor');
      if (after != null && !cursors.add(after)) {
        throw const FormatException('Repeated CRM cursor');
      }
    } while (after != null);
    return rows;
  }

  Future<CrmEntry> get(CrmEntry entry) async {
    if (!canRead(entry.type)) throw const AuthError(403, 'FORBIDDEN');
    final json = RemoteJson(
      await request('GET', '$base/${entry.type.path}/${entry.id}'),
    );
    final row = _parse(json.value['item'], entry.type);
    if (json.number('businessId') != businessId ||
        row.id != entry.id ||
        row.customerId != entry.customerId) {
      throw const FormatException('Unexpected CRM detail');
    }
    return row;
  }

  Future<CrmCommand?> restore() async {
    customers.check();
    if (_sending != null) return pending;
    final value = await storage.read(key: _key);
    customers.check();
    return pending = value == null
        ? null
        : CrmCommand.fromJson(jsonDecode(value));
  }

  Future<CrmEntry> send(CrmCommand command) {
    if (_sending != null) {
      return _sendingKey == command.key
          ? _sending!
          : Future.error(const AuthError(409, 'CRM_PENDING'));
    }
    _sendingKey = command.key;
    _sending = _send(command);
    return _sending!.whenComplete(() {
      _sending = null;
      _sendingKey = null;
    });
  }

  Future<CrmEntry> _send(CrmCommand command) async {
    if (pending != null && pending!.key != command.key) {
      throw const AuthError(409, 'CRM_PENDING');
    }
    await authorize();
    customers.require(
      '${command.type.permission}.${command.id == null ? 'create' : 'update'}',
    );
    pending = command;
    await storage.write(key: _key, value: jsonEncode(command.toJson()));
    try {
      final json = RemoteJson(
        await request(
          command.id == null ? 'POST' : 'PATCH',
          '$base/${command.type.path}${command.id == null ? '' : '/${command.id}'}',
          body: command.body,
          key: command.key,
        ),
      );
      // The computed overdue flag is only present on list/get replies.
      final row = _parse(json.value['item'], command.type);
      if (json.number('businessId') != businessId ||
          row.customerId != command.customerId ||
          command.id != null &&
              (row.id != command.id ||
                  row.revision <= command.body['expectedRevision'])) {
        throw const FormatException('Unexpected CRM result');
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
    if (failure is AuthError) {
      switch (failure.code) {
        case 'FORBIDDEN':
          return 'مجوز این عملیات یا دسترسی به این مشتری را ندارید.';
        case 'CUSTOMER_REQUIRED':
          return 'ابتدا مشتری را انتخاب کنید.';
        case 'REVISION_CONFLICT':
          return 'اطلاعات تغییر کرده؛ نسخه جدید را دریافت کنید.';
        case 'INVALID_STATE':
          return 'برای تغییر نتیجه پیگیری بسته‌شده، ابتدا آن را دوباره باز کنید.';
        case 'RECORD_IN_USE':
          return 'ثبت ارتباط برای مشتری متفرقه مجاز نیست.';
        case 'VALIDATION_FAILED':
          return 'مشخصات، تاریخ و مسئول پیگیری را بررسی کنید.';
        case 'CRM_PENDING':
        case 'IDEMPOTENCY_CONFLICT':
          return 'درخواست قبلی تعیین تکلیف نشده؛ همان درخواست را ادامه دهید.';
        case 'SELECTION_CHANGED':
          return 'نشست یا شعبه تغییر کرده؛ صفحه را دوباره باز کنید.';
        case 'RECORD_NOT_FOUND':
          return 'رکورد در این کسب‌وکار پیدا نشد.';
      }
    }
    if (failure is FormatException) {
      return 'پاسخ سرور معتبر نیست؛ دوباره تلاش کنید.';
    }
    return API.loginError(failure);
  }
}
