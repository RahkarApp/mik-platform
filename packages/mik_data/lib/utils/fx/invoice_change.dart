import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/inventory_quantity.dart';
import '../../source/remote/models/invoice_read.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';
import 'invoice_read.dart';
import 'sale_invoice.dart';
import 'treasury.dart';

class InvoiceChangeSnapshot {
  final RemoteInvoiceDetail detail;
  final Map<String, dynamic> json;
  late final List<Map<String, dynamic>> lines = RemoteJson(json['view']).items(
    'lines',
    (v) => Map<String, dynamic>.unmodifiable(RemoteJson(v).value),
  );
  late final bool posted = RemoteJson(json)
      .items('postings', (v) => RemoteJson(v))
      .isNotEmpty;
  InvoiceChangeSnapshot(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value),
      detail = RemoteInvoiceDetail.fromJson(value);
  int get revision => RemoteJson(json).number('revision');
}

class InvoiceChangeCommand {
  final String key, action, _body;
  final int revision;
  bool attempted;
  Map<String, dynamic>? operation;
  String? retryKey;
  int? retryRevision;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  InvoiceChangeCommand(this.action, Map<String, dynamic> body)
    : key = const Uuid().v4(),
      _body = jsonEncode(body),
      revision = body['expectedRevision'] as int,
      attempted = false;
  InvoiceChangeCommand.fromJson(Object? value) : this._(RemoteJson(value));
  InvoiceChangeCommand._(RemoteJson data)
    : key = data.text('key'),
      action = data.text('action'),
      _body = jsonEncode(RemoteJson(data.value['body']).value),
      revision = RemoteJson(data.value['body']).number('expectedRevision'),
      attempted = data.flag('attempted'),
      operation = data.value['operation'] == null
          ? null
          : RemoteJson(data.value['operation']).value,
      retryKey = data.optionalText('retryKey'),
      retryRevision = data.optionalNumber('retryRevision') {
    if (!Uuid.isValidUUID(fromString: key) ||
        !['amend', 'return', 'cancel', 'convert', 'status'].contains(action) ||
        revision < 1 ||
        retryKey != null && !Uuid.isValidUUID(fromString: retryKey!)) {
      throw const FormatException('Invalid pending invoice change');
    }
  }
  Map<String, Object?> toJson() => {
    'key': key,
    'action': action,
    'body': body,
    'attempted': attempted,
    'operation': operation,
    'retryKey': retryKey,
    'retryRevision': retryRevision,
  };
}

class InvoiceChangeFX {
  final BusinessContext context;
  final RemoteInvoiceSummary invoice;
  final String branchId;
  final FlutterSecureStorage storage;
  late final access = TreasuryFX.forContext(context, branchId);
  late final reader = InvoiceReadFX(context);
  InvoiceChangeCommand? pending;
  bool _sending = false;
  InvoiceChangeFX(
    this.context,
    this.invoice, {
    this.storage = const FlutterSecureStorage(),
  }) : branchId = context.selectedBranch?.branchId ?? '';
  int get businessId => context.session.business.businessId;
  String get _base => '/v1/businesses/$businessId/accounting';
  String get _key =>
      'invoice.change.v2.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId.${invoice.id}';
  void check() {
    context.check();
    if (branchId.isEmpty || context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<Object?> request(
    String method,
    String path, {
    Object? data,
    String? key,
  }) async {
    check();
    final result = await context.auth.request(
      method,
      path,
      branchId: branchId,
      data: data,
      idempotencyKey: key,
    );
    check();
    return result;
  }

  Future<void> authorize() async {
    check();
    await access.authorize();
    await reader.authorize(invoice.type);
    check();
  }

  String permission(String action) => switch (action) {
    'convert' => 'accounting.proforma.convert',
    'amend' => 'accounting.${invoice.type.toLowerCase()}.update',
    'return' =>
      'accounting.${invoice.type == 'PURCHASE' ? 'purchase-return' : 'sale-return'}.create',
    'cancel' =>
      invoice.type == 'PURCHASE'
          ? 'accounting.purchase.delete'
          : invoice.type == 'PROFORMA'
          ? 'accounting.proforma.update'
          : 'accounting.sale.status.cancelled',
    _ => throw const FormatException('Invalid invoice action'),
  };
  bool allowed(String action) => action == 'status'
      ? invoice.type == 'SALE' &&
            ['PENDING', 'READY', 'SHIPPED', 'DELIVERED'].any(deliveryPermission)
      : (invoice.type != 'PROFORMA' || action != 'return') &&
            (action != 'convert' ||
                invoice.type == 'PROFORMA' &&
                    access.has('accounting.sale.create') &&
                    access.has('accounting.sale.read')) &&
            access.has(permission(action)) &&
            (action != 'amend' || access.has('accounting.invoice.amend'));
  bool deliveryPermission(String status) =>
      invoice.type == 'SALE' &&
      switch (status) {
        'PENDING' => access.has('accounting.sale.update'),
        'READY' || 'SHIPPED' || 'DELIVERED' => access.has(
          'accounting.sale.status.${status.toLowerCase()}',
        ),
        _ => false,
      };
  bool canDeliver(InvoiceChangeSnapshot row, String status) {
    const order = ['PENDING', 'READY', 'SHIPPED', 'DELIVERED'];
    final current = row.detail.summary;
    return invoice.type == 'SALE' &&
        current.status == 'ISSUED' &&
        current.operationId == null &&
        deliveryPermission(status) &&
        own(row, 'status') &&
        order.contains(status) &&
        status != current.deliveryStatus &&
        (order.indexOf(status) > order.indexOf(current.deliveryStatus) ||
            current.deliveryStatus == 'READY' && status == 'PENDING');
  }

  Future<InvoiceChangeSnapshot> load() async {
    await authorize();
    final json = RemoteJson(
      await request('GET', '$_base/v2/invoices/${invoice.id}'),
    );
    final row = InvoiceChangeSnapshot(json.value['invoice']);
    final data = row.detail;
    if (json.number('businessId') != businessId ||
        data.businessId != businessId ||
        data.branchId != branchId ||
        data.summary.id != invoice.id ||
        data.summary.rootId != invoice.id ||
        data.summary.type != invoice.type ||
        data.summary.partyId != invoice.partyId ||
        row.revision < 1) {
      throw const FormatException('Unexpected invoice snapshot');
    }
    // A correction is authorized against the root revision; its effective view supplies editable values.
    row.lines;
    row.posted;
    RemoteJson(row.json['createdBy']).text('identityId');
    return row;
  }

  bool own(InvoiceChangeSnapshot row, String action) {
    // Conversion reads the source with its read grant; the server applies the
    // separate convert and sale.create grants, without an update ownership rule.
    if (action == 'convert') return true;
    final owner = context.session.business.membershipType == 'OWNER';
    final created = RemoteJson(row.json['createdBy']).text('identityId');
    return owner ||
        created == context.session.identityId ||
        access.has('accounting.${invoice.type.toLowerCase()}.update.all');
  }

  static BigInt units(String value) {
    final normalized = InventoryQuantity.fromJson(value).toString().split('.');
    return BigInt.parse(normalized.first) * BigInt.from(1000000) +
        BigInt.parse(
          (normalized.length == 1 ? '' : normalized.last).padRight(6, '0'),
        );
  }

  Future<InvoiceChangeCommand?> restore() async {
    check();
    if (_sending) return pending;
    return _readSaved();
  }

  Future<InvoiceChangeCommand?> _readSaved() async {
    final value = await storage.read(key: _key);
    check();
    final saved = value == null
        ? null
        : InvoiceChangeCommand.fromJson(jsonDecode(value));
    if (saved != null && saved.body['invoiceId'] != invoice.id) {
      throw const FormatException('Unexpected pending invoice');
    }
    if (saved?.operation != null) _operation(saved!.operation!, saved);
    return pending = saved;
  }

  Future<void> persist() async {
    check();
    await storage.write(key: _key, value: jsonEncode(pending!.toJson()));
    check();
  }

  RemoteJson _operation(Object? value, InvoiceChangeCommand command) {
    final row = RemoteJson(value);
    if (!Uuid.isValidUUID(fromString: row.text('operationId')) ||
        row.text('command') != 'invoice.${command.action}.v2' ||
        row.number('revision') < 1 ||
        ![
          'PENDING',
          'PROCESSING',
          'RETRY',
          'ACTION_REQUIRED',
          'SUCCEEDED',
          'FAILED',
        ].contains(row.text('status'))) {
      throw const FormatException('Invalid invoice operation');
    }
    if (row.text('status') == 'SUCCEEDED') {
      final result = RemoteJson(row.value['result']);
      if (command.action == 'convert') {
        final id = result.text('invoiceId');
        if (!Uuid.isValidUUID(fromString: id) ||
            id == invoice.id ||
            result.text('rootInvoiceId') != id ||
            result.number('revision') < 1) {
          throw const FormatException('Unexpected proforma conversion result');
        }
      } else if (result.text('invoiceId') != invoice.id ||
          result.text('rootInvoiceId') != invoice.id ||
          result.number('revision') <= command.revision) {
        throw const FormatException('Unexpected invoice change result');
      }
    }
    return row;
  }

  Future<void> accept(Object? value) async {
    final json = RemoteJson(value);
    if (json.number('businessId') != businessId) {
      throw const FormatException('Unexpected operation business');
    }
    final row = _operation(json.value['operation'], pending!);
    final old = pending!.operation;
    if (old != null &&
        (old['operationId'] != row.text('operationId') ||
            row.number('revision') < (old['revision'] as int))) {
      throw const FormatException('Operation changed unexpectedly');
    }
    pending!.operation = Map.of(row.value);
    if (pending!.retryRevision != null &&
        row.number('revision') > pending!.retryRevision!) {
      pending!.retryKey = null;
      pending!.retryRevision = null;
    }
    await persist();
  }

  Future<void> send(InvoiceChangeCommand command) async {
    if (_sending) throw const AuthError(409, 'INVOICE_OPERATION_PENDING');
    _sending = true;
    try {
      pending ??= await _readSaved();
      if (pending != null && pending!.key != command.key) {
        throw const AuthError(409, 'INVOICE_OPERATION_PENDING');
      }
      await authorize();
      if (command.operation != null) {
        await refresh();
        return;
      }
      if (!allowed(command.action)) throw const AuthError(403, 'FORBIDDEN');
      if (command.action == 'status' &&
          !deliveryPermission(RemoteJson(command.body).text('status'))) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      if (command.action == 'convert' &&
          (command.body['type'] != 'SALE' ||
              command.body['deliveryStatus'] != 'PENDING')) {
        throw const FormatException('Unexpected conversion request');
      }
      if (command.body['invoiceId'] != invoice.id) {
        throw const FormatException('Unexpected invoice command');
      }
      final previousAttempt = command.attempted;
      pending = command;
      command.attempted = true;
      await persist();
      try {
        await accept(
          await request(
            'POST',
            '$_base/v2/invoices/${command.action}',
            data: command.body,
            key: command.key,
          ),
        );
      } on AuthError catch (error) {
        // A lost acceptance reply must retain its exact key/body, even if a later revision check fails.
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

  Future<void> refresh() async {
    check();
    final op = pending?.operation;
    if (op == null) throw const AuthError(409, 'INVOICE_OPERATION_PENDING');
    await accept(
      await request('GET', '$_base/operations/${op['operationId']}'),
    );
  }

  Future<void> retry() async {
    if (_sending) throw const AuthError(409, 'INVOICE_OPERATION_PENDING');
    await authorize();
    final command = pending;
    final op = command?.operation;
    if (command == null ||
        op == null ||
        !access.has('accounting.invoice.amend') ||
        !allowed(command.action)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    if (!['RETRY', 'ACTION_REQUIRED'].contains(op['status'])) {
      throw const AuthError(409, 'INVALID_STATE');
    }
    _sending = true;
    try {
      command.retryKey ??= const Uuid().v4();
      command.retryRevision ??= op['revision'] as int;
      await persist();
      await accept(
        await request(
          'POST',
          '$_base/operations/retry',
          data: {
            'operationId': op['operationId'],
            'expectedRevision': command.retryRevision,
          },
          key: command.retryKey,
        ),
      );
    } finally {
      _sending = false;
    }
  }

  Future<InvoiceChangeSnapshot> finish() async {
    final command = pending;
    final op = command?.operation;
    if (op == null || !['SUCCEEDED', 'FAILED'].contains(op['status'])) {
      throw const AuthError(409, 'INVOICE_OPERATION_PENDING');
    }
    final row = await load();
    if (op['status'] == 'SUCCEEDED' && command!.action == 'convert') {
      final targetId = RemoteJson(op['result']).text('invoiceId');
      final target = await reader.detail(targetId, 'SALE');
      if (row.detail.summary.status != 'CONVERTED' ||
          row.revision <= command.revision ||
          row.detail.convertedInvoiceId != targetId ||
          target.summary.revision <
              RemoteJson(op['result']).number('revision') ||
          target.referenceInvoiceId != invoice.id ||
          target.summary.rootId != targetId ||
          target.summary.partyId != invoice.partyId ||
          target.summary.status != 'ISSUED') {
        throw const FormatException('Conversion not confirmed');
      }
    } else if (op['status'] == 'SUCCEEDED' &&
        (row.revision < (RemoteJson(op['result']).number('revision')) ||
            command!.action == 'cancel' &&
                row.detail.summary.status != 'CANCELLED' ||
            command.action == 'status' &&
                (row.detail.summary.deliveryStatus != command.body['status'] ||
                    ['SHIPPED', 'DELIVERED'].contains(command.body['status']) &&
                        !row.posted))) {
      throw const FormatException('Invoice not confirmed after operation');
    }
    await storage.delete(key: _key);
    pending = null;
    return row;
  }

  static String message(Object error) {
    if (error is AuthError) {
      switch (error.code) {
        case 'REVISION_CONFLICT':
          return 'فاکتور تغییر کرده است؛ اطلاعات جدید را دریافت و اصلاح را دوباره انجام دهید.';
        case 'PROFORMA_EXPIRED':
          return 'مهلت اعتبار پیش‌فاکتور گذشته است؛ تبدیل آن به فروش امکان‌پذیر نیست.';
        case 'INVOICE_OPERATION_PENDING':
          return 'عملیات قبلی هنوز تعیین تکلیف نشده است؛ همان عملیات را پیگیری کنید.';
        case 'INVALID_STATE':
          return 'وضعیت فاکتور اجازهٔ این عملیات را نمی‌دهد؛ فروش ارسال‌شده به مرجوعی واقعی نیاز دارد.';
        case 'FORBIDDEN':
          return 'مجوز اصلاح این فاکتور یا عملیات انبار وابسته را ندارید.';
        case 'SETTLEMENT_EXCEEDED':
          return 'مبالغ اصلاح با تسویهٔ فعلی سازگار نیست؛ اطلاعات را تازه کنید.';
      }
    }
    return SaleInvoiceFX.message(error);
  }
}
