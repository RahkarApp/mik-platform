import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/remote_json.dart';
import '../../source/remote/models/scope_authorization.dart';
import 'business_context.dart';

class SalePaymentTarget {
  final String id, name, kind;
  final String? branchId, fundId;
  SalePaymentTarget.fromJson(Object? value, {required bool terminal})
    : this._(RemoteJson(value), terminal);
  SalePaymentTarget._(RemoteJson json, bool terminal)
    : id = json.text(terminal ? 'terminalId' : 'fundId'),
      name = json.text('name'),
      kind = terminal ? 'TERMINAL' : json.text('kind'),
      branchId = json.optionalText('branchId'),
      fundId = terminal ? json.text('fundId') : null {
    if (!Uuid.isValidUUID(fromString: id) ||
        !['CASH', 'PETTY_CASH', 'BANK', 'TERMINAL'].contains(kind) ||
        branchId != null && !Uuid.isValidUUID(fromString: branchId!) ||
        kind != 'BANK' && branchId == null ||
        kind == 'BANK' && branchId != null ||
        fundId != null && !Uuid.isValidUUID(fromString: fundId!)) {
      throw const FormatException('Invalid payment destination');
    }
  }
  bool accepts(String method, {String direction = 'IN'}) => switch (method) {
    'CASH' => ['CASH', 'PETTY_CASH'].contains(kind),
    'BANK_TRANSFER' => kind == 'BANK',
    'CARD' => kind == (direction == 'OUT' ? 'BANK' : 'TERMINAL'),
    'CHEQUE' => direction == 'OUT' && kind == 'BANK',
    _ => false,
  };
  Map<String, String> get routing => {
    kind == 'TERMINAL' ? 'terminalId' : 'fundId': id,
  };
}

class SaleOperation {
  final String id, status;
  final int revision;
  final String? invoiceId, errorCode;
  final Map<String, dynamic> _json;
  SaleOperation.fromJson(Object? value) : this._(RemoteJson(value));
  SaleOperation._(RemoteJson json)
    : id = json.text('operationId'),
      status = json.text('status'),
      revision = json.number('revision'),
      errorCode = json.optionalText('errorCode'),
      invoiceId = json.value['result'] == null
          ? null
          : RemoteJson(json.value['result']).text('invoiceId'),
      _json = Map.unmodifiable(json.value) {
    if (!Uuid.isValidUUID(fromString: id) ||
        revision < 1 ||
        json.text('command') != 'invoice.create.v2' ||
        ![
          'PENDING',
          'PROCESSING',
          'RETRY',
          'ACTION_REQUIRED',
          'SUCCEEDED',
          'FAILED',
        ].contains(status) ||
        status == 'SUCCEEDED' &&
            (invoiceId == null || !Uuid.isValidUUID(fromString: invoiceId!))) {
      throw const FormatException('Unexpected sale operation');
    }
  }
  Map<String, dynamic> toJson() => Map.of(_json);
}

class SaleInvoiceResult {
  final String id, number, status, paymentStatus;
  final int total;
  SaleInvoiceResult.fromJson(
    Object? value,
    int businessId,
    String branchId,
    String id, {
    String type = 'SALE',
  }) : this._(RemoteJson(value), businessId, branchId, id, type);
  SaleInvoiceResult._(
    RemoteJson json,
    int businessId,
    String branchId,
    String expected,
    String type,
  ) : id = json.text('invoiceId'),
      number = json.text('number'),
      status = json.text('status'),
      paymentStatus = json.text('paymentStatus'),
      total = RemoteJson(json.value['totals']).number('total') {
    if (id != expected ||
        json.number('businessId') != businessId ||
        json.text('branchId') != branchId ||
        json.text('type') != type ||
        type == 'PURCHASE' && json.text('deliveryStatus') != 'DELIVERED' ||
        status != 'ISSUED' ||
        !['UNPAID', 'PARTIALLY_PAID', 'PAID'].contains(paymentStatus) ||
        RemoteJson(json.value['totals']).text('currency') != 'TOMAN' ||
        total < 0 ||
        total > 9007199254740991) {
      throw const FormatException('Unexpected issued invoice');
    }
  }
}

class SaleInvoiceCommand {
  final String key, _body;
  bool attempted;
  SaleOperation? operation;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  SaleInvoiceCommand(Map<String, dynamic> body)
    : key = const Uuid().v4(),
      _body = jsonEncode(body),
      attempted = false;
  SaleInvoiceCommand.fromJson(Object? value) : this._(RemoteJson(value));
  SaleInvoiceCommand._(RemoteJson json)
    : key = json.text('key'),
      _body = jsonEncode(RemoteJson(json.value['body']).value),
      attempted = json.flag('attempted'),
      operation = json.value['operation'] == null
          ? null
          : SaleOperation.fromJson(json.value['operation']) {
    if (!Uuid.isValidUUID(fromString: key) ||
        !['SALE', 'PURCHASE', 'PROFORMA'].contains(body['type'])) {
      throw const FormatException('Invalid saved sale command');
    }
  }
  Map<String, Object?> toJson() => {
    'key': key,
    'body': body,
    'attempted': attempted,
    'operation': operation?.toJson(),
  };
}

class SaleInvoiceFX {
  // Invoice creation shares the durable accounting operation lifecycle.
  final String type;
  String get _permission => type.toLowerCase();
  final BusinessContext context;
  final FlutterSecureStorage storage;
  final String branchId;
  ScopeAuthorization? _authorization;
  SaleInvoiceCommand? pending;
  Future<SaleOperation>? _running;
  SaleInvoiceFX({
    required this.context,
    this.type = 'SALE',
    this.storage = const FlutterSecureStorage(),
  }) : branchId = context.selectedBranch?.branchId ?? '' {
    if (!['SALE', 'PURCHASE', 'PROFORMA'].contains(type)) {
      throw ArgumentError.value(type, 'type');
    }
  }
  int get businessId => context.session.business.businessId;
  String get _base => '/v1/businesses/$businessId/accounting';
  String get _storeKey =>
      '$_permission.v2.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId';
  void check() {
    context.check();
    if (!identical(BusinessContext.forApp(context.auth.appId), context) ||
        branchId.isEmpty ||
        context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<void> authorize() async {
    check();
    _authorization = null;
    final result = ScopeAuthorization.fromJson(
      await context.auth.request(
        'GET',
        '/v1/businesses/$businessId/authorization',
        query: {'scopeType': 'BRANCH', 'scopeId': branchId},
      ),
    );
    check();
    if (!result.allowed ||
        result.businessId != businessId ||
        result.scopeType != 'BRANCH' ||
        result.scopeId != branchId ||
        result.membershipId != context.session.business.membershipId) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    _authorization = result;
  }

  bool has(String permission) =>
      context.valid &&
      context.selectedBranch?.branchId == branchId &&
      _authorization?.permissionCodes.contains(permission) == true;

  void require(String permission) {
    check();
    if (_authorization?.permissionCodes.contains(permission) != true) {
      throw const AuthError(403, 'FORBIDDEN');
    }
  }

  Future<void> authorizePayment({bool bank = false}) async {
    require('accounting.payment.allocate');
    if (!['SALE', 'PURCHASE'].contains(type)) {
      throw const FormatException('Invoice payment is not supported');
    }
    require(
      type == 'PURCHASE'
          ? 'accounting.purchase.payment.pay'
          : 'accounting.sale.payment.receive',
    );
    require('accounting.treasury.use');
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
        result.membershipId != context.session.business.membershipId ||
        result.scopeType != 'BUSINESS' ||
        result.scopeId != '$businessId') {
      throw const FormatException('Unexpected payment authorization');
    }
    if (!result.permissionCodes.contains('accounting.payment.create') ||
        bank && !result.permissionCodes.contains('accounting.bank.use')) {
      throw const AuthError(403, 'FORBIDDEN');
    }
  }

  Future<List<SalePaymentTarget>> paymentTargets(String method) async {
    if (![
      'CASH',
      'CARD',
      'BANK_TRANSFER',
      if (type == 'PURCHASE') 'CHEQUE',
    ].contains(method)) {
      throw const FormatException('Unsupported sale payment method');
    }
    await authorizePayment(
      bank:
          method == 'BANK_TRANSFER' ||
          type == 'PURCHASE' && ['CARD', 'CHEQUE'].contains(method),
    );
    if (method == 'CHEQUE') require('accounting.purchase.cheque.pay');
    final terminal = method == 'CARD' && type != 'PURCHASE',
        rows = <SalePaymentTarget>[];
    final ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await context.request(
          'GET',
          '$_base/treasury/options',
          query: {
            'kind': terminal ? 'terminal' : 'fund',
            'limit': '100',
            'after': ?after,
          },
        ),
      );
      check();
      final items = json.items(
        'items',
        (v) => SalePaymentTarget.fromJson(v, terminal: terminal),
      );
      if (json.number('businessId') != businessId ||
          items.any(
            (r) =>
                !ids.add(r.id) || r.branchId != null && r.branchId != branchId,
          )) {
        throw const FormatException('Unexpected payment options scope');
      }
      rows.addAll(
        items.where(
          (r) =>
              r.accepts(method, direction: type == 'PURCHASE' ? 'OUT' : 'IN'),
        ),
      );
      after = json.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Repeated payment options cursor');
      }
    } while (after != null);
    return rows;
  }

  Future<SaleInvoiceCommand?> restore() async {
    check();
    final value = await storage.read(key: _storeKey);
    check();
    final command = value == null
        ? null
        : SaleInvoiceCommand.fromJson(jsonDecode(value));
    if (command != null && command.body['type'] != type) {
      throw const FormatException('Unexpected saved invoice type');
    }
    return pending = command;
  }

  Future<void> _persist() async {
    await storage.write(key: _storeKey, value: jsonEncode(pending!.toJson()));
    check();
  }

  Future<SaleOperation> send(SaleInvoiceCommand command) {
    if (_running != null) {
      if (pending?.key != command.key) {
        return Future.error(const AuthError(409, 'SALE_PENDING'));
      }
      return _running!;
    }
    final future = _send(command);
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  Future<SaleOperation> _send(SaleInvoiceCommand command) async {
    require('accounting.$_permission.read');
    if (command.body['type'] != type) {
      throw const FormatException('Unexpected invoice type');
    }
    if (pending != null && pending!.key != command.key) {
      throw const AuthError(409, 'SALE_PENDING');
    }
    if (command.operation != null) return refresh();
    require('accounting.$_permission.create');
    if (type == 'SALE') require('accounting.sale.status.delivered');
    final previouslyAttempted = command.attempted;
    pending = command;
    command.attempted = true;
    await _persist();
    try {
      return await _accept(
        await context.request(
          'POST',
          '$_base/v2/invoices',
          data: command.body,
          idempotencyKey: command.key,
        ),
      );
    } on AuthError catch (error) {
      // Once a response was lost, a later validation failure cannot prove that
      // the original invoice was never created. Keep that original key/body.
      if (!previouslyAttempted &&
          error.statusCode < 500 &&
          !error.retryable &&
          !error.requiresLogin &&
          error.statusCode != 403 &&
          error.code != 'IDEMPOTENCY_CONFLICT' &&
          error.code != 'SELECTION_CHANGED') {
        await storage.delete(key: _storeKey);
        pending = null;
      }
      rethrow;
    }
  }

  Future<SaleOperation> _accept(Object? value) async {
    check();
    final json = RemoteJson(value);
    if (json.number('businessId') != businessId) {
      throw const FormatException('Unexpected sale business');
    }
    final op = SaleOperation.fromJson(json.value['operation']);
    final previous = pending!.operation;
    if (previous != null &&
        (previous.id != op.id || op.revision < previous.revision)) {
      throw const FormatException('Unexpected sale operation revision');
    }
    pending!.operation = op;
    await _persist();
    return op;
  }

  Future<SaleOperation> refresh() async {
    require('accounting.$_permission.read');
    final op = pending?.operation;
    if (op == null) throw const AuthError(409, 'SALE_PENDING');
    return _accept(await context.request('GET', '$_base/operations/${op.id}'));
  }

  Future<SaleInvoiceResult> invoice() async {
    require('accounting.$_permission.read');
    final op = pending?.operation;
    if (op?.status != 'SUCCEEDED') throw const AuthError(409, 'SALE_PENDING');
    final json = RemoteJson(
      await context.request('GET', '$_base/v2/invoices/${op!.invoiceId}'),
    );
    check();
    if (json.number('businessId') != businessId) {
      throw const FormatException('Unexpected sale business');
    }
    return SaleInvoiceResult.fromJson(
      json.value['invoice'],
      businessId,
      branchId,
      op.invoiceId!,
      type: type,
    );
  }

  Future<void> clearFinished() async {
    check();
    if (!['SUCCEEDED', 'FAILED'].contains(pending?.operation?.status)) {
      throw const AuthError(409, 'SALE_PENDING');
    }
    await storage.delete(key: _storeKey);
    pending = null;
  }

  static String message(Object error) {
    if (error is AuthError) {
      switch (error.code) {
        case 'FORBIDDEN':
          return 'مجوز لازم برای ثبت یا مشاهده این فاکتور را ندارید.';
        case 'SALE_PENDING':
        case 'IDEMPOTENCY_CONFLICT':
          return 'درخواست قبلی تعیین تکلیف نشده؛ همان درخواست را پیگیری کنید.';
        case 'CREDIT_SALES_DISABLED':
          return 'فروش اعتباری در تنظیمات کسب‌وکار غیرفعال است.';
        case 'DEFAULT_CUSTOMER_CREDIT_FORBIDDEN':
          return 'فاکتور مشتری متفرقه باید کامل پرداخت شود؛ فعلاً مشتری مشخص انتخاب کنید.';
        case 'INSUFFICIENT_STOCK':
          return 'موجودی قابل فروش برای ثبت فاکتور کافی نیست.';
        case 'PRICE_UNAVAILABLE':
          return 'قیمت یکی از اقلام معتبر نیست؛ قیمت را دوباره انتخاب کنید.';
        case 'VALIDATION_FAILED':
          return 'اطلاعات فاکتور، مشتری و تعداد اقلام را بررسی کنید.';
        case 'SELECTION_CHANGED':
          return 'نشست یا شعبه تغییر کرده؛ صفحه را دوباره باز کنید.';
        default:
          if (!error.requiresLogin && error.statusCode < 500) {
            return 'ثبت فاکتور انجام نشد؛ کد خطای سرور: ${error.code}';
          }
      }
    }
    if (error is FormatException) {
      return 'پاسخ سرور کامل نیست؛ درخواست قبلی را پیگیری کنید.';
    }
    return API.loginError(error);
  }
}
