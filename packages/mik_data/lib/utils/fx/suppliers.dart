import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/remote_json.dart';
import '../../source/remote/models/scope_authorization.dart';
import '../../source/remote/models/supplier.dart';
import 'business_context.dart';

class SuppliersFX {
  static final _contexts = Expando<Map<String, SuppliersFX>>();
  static SuppliersFX forContext(
    BusinessContext context, {
    AccountingPersonType type = AccountingPersonType.supplier,
  }) {
    final clients = _contexts[context] ??= {};
    return clients['${type.name}.${context.selectedBranch?.branchId ?? ''}'] ??=
        SuppliersFX(context: context, type: type);
  }

  final BusinessContext context;
  final AccountingPersonType type;
  final FlutterSecureStorage storage;
  final String? branchId;
  final accessVersion = 0.obs;
  ScopeAuthorization? _authorization;
  SupplierCommand? pending;
  Future<RemoteSupplier>? _sending;
  String? _sendingKey;
  SuppliersFX({
    required this.context,
    this.type = AccountingPersonType.supplier,
    this.storage = const FlutterSecureStorage(),
  }) : branchId = context.selectedBranch?.branchId;
  int get businessId => context.session.business.businessId;
  String get _base => '/v1/businesses/$businessId/accounting/${type.path}';
  String get _key =>
      '${type.storage}.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId';
  void check() {
    context.check();
    if (!identical(context, BusinessContext.forApp(context.auth.appId)) ||
        branchId == null ||
        context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  bool has(String code) {
    accessVersion.value;
    return context.valid &&
        branchId != null &&
        context.selectedBranch?.branchId == branchId &&
        _authorization?.permissionCodes.contains(code) == true;
  }

  bool canEdit(RemoteSupplier row) =>
      row.type == type &&
      row.businessId == businessId &&
      has(type.updatePermission) &&
      (type == AccountingPersonType.partner ||
          context.session.business.membershipType == 'OWNER' ||
          row.creatorIdentityId == context.session.identityId ||
          has('${type.permission}.update.all'));

  void require(String code) {
    check();
    if (!has(code)) throw const AuthError(403, 'FORBIDDEN');
  }

  Future<void> authorize() async {
    check();
    _authorization = null;
    accessVersion.value++;
    final result = ScopeAuthorization.fromJson(
      await context.auth.request(
        'GET',
        '/v1/businesses/$businessId/authorization',
        query: {'scopeType': 'BUSINESS', 'scopeId': '$businessId'},
      ),
    );
    check();
    if (!result.allowed ||
        result.businessId != businessId ||
        result.scopeType != 'BUSINESS' ||
        result.scopeId != '$businessId' ||
        result.membershipId != context.session.business.membershipId) {
      throw const FormatException('Unexpected supplier authorization');
    }
    _authorization = result;
    accessVersion.value++;
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? key,
  }) async {
    check();
    try {
      final result = await context.request(
        method,
        path,
        query: query,
        data: body,
        idempotencyKey: key,
      );
      check();
      return result;
    } on AuthError catch (failure) {
      if (failure.statusCode == 403 || failure.requiresLogin) {
        _authorization = null;
        accessVersion.value++;
      }
      rethrow;
    }
  }

  RemoteSupplier _supplier(Object? value) {
    final row = RemoteSupplier.fromJson(value, type: type);
    if (row.businessId != businessId) {
      throw const FormatException('Unexpected supplier business');
    }
    return row;
  }

  Future<List<RemoteSupplier>> all({String status = 'ACTIVE'}) async {
    if (!['ACTIVE', 'ARCHIVED'].contains(status)) {
      throw const FormatException('Invalid supplier status');
    }
    require('${type.permission}.read');
    // The supplier API has no search parameter; load every page before local filtering.
    final rows = <RemoteSupplier>[], cursors = <String>{}, ids = <String>{};
    String? cursor;
    do {
      final json = RemoteJson(
        await _request(
          'GET',
          _base,
          query: {'limit': '100', 'status': status, 'after': ?cursor},
        ),
      );
      final items = json.items('items', _supplier);
      if (json.number('businessId') != businessId ||
          items.any((row) => row.status != status || !ids.add(row.id))) {
        throw const FormatException('Unexpected supplier page');
      }
      rows.addAll(items);
      cursor = json.optionalText('nextCursor');
      if (cursor != null && !cursors.add(cursor)) {
        throw const FormatException('Repeated supplier cursor');
      }
    } while (cursor != null);
    return rows;
  }

  Future<RemoteSupplier> get(String id) async {
    require('${type.permission}.read');
    final json = RemoteJson(
      await _request('GET', '$_base/${Uri.encodeComponent(id)}'),
    );
    final item = _supplier(json.value['item']);
    if (json.number('businessId') != businessId || item.id != id) {
      throw const FormatException('Unexpected supplier result');
    }
    return item;
  }

  Future<SupplierCommand?> restore() async {
    check();
    if (_sending != null) return pending;
    final saved = await storage.read(key: _key);
    check();
    final restored = saved == null
        ? null
        : SupplierCommand.fromJson(jsonDecode(saved));
    if (restored != null && restored.type != type) {
      throw const FormatException('Unexpected accounting person command');
    }
    return pending = restored;
  }

  Future<RemoteSupplier> send(SupplierCommand command) {
    if (_sending != null) {
      if (_sendingKey != command.key) {
        return Future.error(const AuthError(409, 'SUPPLIER_PENDING'));
      }
      return _sending!;
    }
    _sendingKey = command.key;
    final result = _send(command);
    _sending = result;
    return result.whenComplete(() {
      _sending = null;
      _sendingKey = null;
    });
  }

  Future<RemoteSupplier> _send(SupplierCommand command) async {
    if (command.type != type) {
      throw const FormatException('Unexpected accounting person command');
    }
    if (pending != null && pending!.key != command.key) {
      throw const AuthError(409, 'SUPPLIER_PENDING');
    }
    await authorize();
    require(command.updating ? type.updatePermission : type.createPermission);
    if (command.updating) {
      final current = await get(command.body[type.idField] as String);
      if (!canEdit(current)) throw const AuthError(403, 'FORBIDDEN');
      // Do not replace expectedRevision: the server must detect concurrent edits.
    }
    pending = command;
    // Keep the exact body/key until confirmation: a lost reply may already be committed.
    await storage.write(key: _key, value: jsonEncode(command.toJson()));
    try {
      final json = RemoteJson(
        await _request(
          'POST',
          command.version == 1
              ? _base
              : '/v1/businesses/$businessId/accounting/v2/${type.path}${command.updating ? '/update' : ''}',
          body: command.body,
          key: command.key,
        ),
      );
      final row = _supplier(json.value[type.resultField]);
      if (json.number('businessId') != businessId ||
          row.status != (command.body['status'] ?? 'ACTIVE') ||
          row.name != command.body['name'] ||
          row.phone != command.body['phone'] ||
          command.updating &&
              (row.id != command.body[type.idField] ||
                  row.revision <= command.body['expectedRevision']) ||
          command.version == 2 && row.kind != command.body['kind']) {
        throw const FormatException('Unexpected created supplier');
      }
      if (type == AccountingPersonType.partner) {
        // Keep the command for exact retry if the reply doesn't confirm its details.
        for (final field in ['legalName', 'reference', 'note']) {
          if (command.body.containsKey(field) &&
              row.profile[field] != command.body[field]) {
            throw const FormatException(
              'Unexpected partner profile confirmation',
            );
          }
        }
      }
      await storage.delete(key: _key);
      pending = null;
      return row;
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

  static String message(
    Object failure, {
    AccountingPersonType type = AccountingPersonType.supplier,
  }) => _message(failure).replaceAll('تامین‌کننده', type.singular);

  static String _message(Object failure) {
    if (failure is AuthError) {
      switch (failure.code) {
        case 'FORBIDDEN':
          return 'مجوز انجام این عملیات روی تامین‌کننده را ندارید.';
        case 'RECORD_IN_USE':
          return 'این تامین‌کننده مانده حساب، سهم مالکیت یا وام باز دارد و فعلاً قابل آرشیو نیست.';
        case 'BATCH_LIMIT':
          return 'تعداد رکوردهای فعال به سقف مجاز سرور رسیده است.';
        case 'REVISION_CONFLICT':
          return 'اطلاعات تامین‌کننده تغییر کرده است؛ فرم را ببندید و نسخه جدید را دریافت کنید.';
        case 'SUPPLIER_PENDING':
        case 'IDEMPOTENCY_CONFLICT':
          return 'درخواست قبلی تعیین تکلیف نشده؛ همان درخواست را ادامه دهید.';
        case 'VALIDATION_FAILED':
          return 'مشخصات تامین‌کننده، نوع شخص، شماره موبایل و آدرس‌ها را بررسی کنید.';
        case 'SELECTION_CHANGED':
          return 'نشست یا شعبه تغییر کرده است؛ صفحه را دوباره باز کنید.';
        case 'RECORD_NOT_FOUND':
          return 'این تامین‌کننده در کسب‌وکار انتخاب‌شده پیدا نشد.';
        default:
          if (!failure.requiresLogin && failure.statusCode < 500) {
            return 'عملیات انجام نشد؛ کد خطای سرور: ${failure.code}';
          }
      }
    }
    if (failure is FormatException) {
      return 'پاسخ سرور کامل نیست؛ دوباره تلاش کنید.';
    }
    return API.loginError(failure);
  }
}
