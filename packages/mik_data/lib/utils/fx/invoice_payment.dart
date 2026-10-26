import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/invoice_payment.dart';
import '../../source/remote/models/invoice_read.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';
import 'invoice_read.dart';
import 'sale_invoice.dart';
import 'treasury.dart';

class InvoicePaymentCommand {
  final String key, action, _body;
  final String? _before;
  Map<String, dynamic>? get before =>
      _before == null ? null : jsonDecode(_before) as Map<String, dynamic>;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  InvoicePaymentCommand(
    this.action,
    Map<String, dynamic> body, {
    Map<String, dynamic>? before,
  }) : key = const Uuid().v4(),
       _body = jsonEncode(body),
       _before = before == null ? null : jsonEncode(before);
  InvoicePaymentCommand.fromJson(Object? value) : this._(RemoteJson(value));
  InvoicePaymentCommand._(RemoteJson json)
    : key = json.text('key'),
      action = json.text('action'),
      _body = jsonEncode(RemoteJson(json.value['body']).value),
      _before = json.value['before'] == null
          ? null
          : jsonEncode(RemoteJson(json.value['before']).value) {
    if (!Uuid.isValidUUID(fromString: key) ||
        ![
          'PAYMENT',
          'REFUND',
          'ALLOCATE',
          'REVERSE_PAYMENT',
          'REVERSE_ALLOCATION',
        ].contains(action)) {
      throw const FormatException('Invalid pending payment');
    }
  }
  Map<String, Object> toJson() => {
    'key': key,
    'action': action,
    'body': body,
    if (_before != null) 'before': before!,
  };
}

class InvoicePaymentFX {
  final BusinessContext context;
  final RemoteInvoiceSummary? _invoice;
  final String partyType, partyId;
  RemoteInvoiceSummary get invoice =>
      _invoice ?? (throw StateError('This payment has no invoice'));
  final FlutterSecureStorage storage;
  late final access = TreasuryFX.forContext(context, branchId);
  late final reader = InvoiceReadFX(context);
  final String branchId;
  InvoicePaymentCommand? pending;
  Future<void>? _sending;
  InvoicePaymentFX(
    this.context,
    RemoteInvoiceSummary invoice, {
    this.storage = const FlutterSecureStorage(),
  }) : _invoice = invoice,
       partyType = invoice.partyType,
       partyId = invoice.partyId,
       branchId = context.selectedBranch?.branchId ?? '';

  // Direct party payments use the same routing, durable retry and receipt checks.
  InvoicePaymentFX.forParty(
    this.context,
    this.partyType,
    this.partyId, {
    this.storage = const FlutterSecureStorage(),
  }) : _invoice = null,
       branchId = context.selectedBranch?.branchId ?? '';
  int get businessId => context.session.business.businessId;
  String get _base => '/v1/businesses/$businessId/accounting';
  String get _key =>
      'invoice.payment.v2.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId.${_invoice?.id ?? 'party.$partyType.$partyId'}';
  String get direction => partyType == 'CUSTOMER' ? 'IN' : 'OUT';
  bool get canCreate =>
      access.has('accounting.payment.create', business: true) &&
      access.has('accounting.payment.allocate') &&
      access.has('accounting.treasury.use');
  bool get canRefund =>
      canCreate && access.has('accounting.payment.refund', business: true);
  String get refundDirection => direction == 'IN' ? 'OUT' : 'IN';
  bool get canReadPayments =>
      access.has('accounting.payment.read', business: true);
  bool get canReadAllocations =>
      access.has('accounting.payment.allocate', business: true);
  bool get canReversePayment =>
      canReadPayments &&
      access.has('accounting.payment.reverse', business: true) &&
      access.has('accounting.payment.allocate') &&
      access.has('accounting.treasury.use');
  bool get canReverseAllocation =>
      canReadAllocations &&
      access.has('accounting.payment.reverse', business: true) &&
      access.has('accounting.payment.allocate');
  bool get canReadSources =>
      access.has('accounting.account.read', business: true);
  bool get canAllocate =>
      canReadSources &&
      access.has('accounting.payment.create', business: true) &&
      access.has('accounting.payment.allocate');
  void check() {
    context.check();
    if (branchId.isEmpty || context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<void> authorize() async {
    check();
    if (!['CUSTOMER', 'SUPPLIER'].contains(partyType) ||
        !Uuid.isValidUUID(fromString: partyId)) {
      throw const FormatException('Invalid payment party');
    }
    await access.authorize();
    check();
  }

  Future<Object?> _request(
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

  void _party(int business, String party, String type) {
    if (business != businessId || party != partyId || type != partyType) {
      throw const FormatException('Unexpected payment party');
    }
  }

  void _document(InvoiceSettlementDocument row) {
    _party(row.businessId, row.partyId, row.partyType);
    if (row.branchId != branchId || row.rootId != invoice.rootId) {
      throw const FormatException('Unexpected settlement document');
    }
  }

  Future<
    ({
      RemoteInvoiceDetail detail,
      List<InvoiceSettlementDocument> documents,
      bool anonymous,
    })
  >
  invoiceDetails() async {
    await reader.authorize(invoice.type);
    final json = RemoteJson(
      await _request('GET', '$_base/v2/invoices/${invoice.id}'),
    );
    final detail = RemoteInvoiceDetail.fromJson(json.value['invoice']);
    _party(detail.businessId, detail.summary.partyId, detail.summary.partyType);
    if (json.number('businessId') != businessId ||
        detail.summary.id != invoice.id ||
        detail.branchId != branchId ||
        detail.summary.type != invoice.type) {
      throw const FormatException('Unexpected invoice');
    }
    final raw = RemoteJson(json.value['invoice']);
    final docs = <InvoiceSettlementDocument>[];
    // The family view is a total; allocation must target each stored debit document.
    final root = InvoiceSettlementDocument.fromJson(raw.value);
    _document(root);
    docs.add(root);
    final seen = <String>{root.id};
    for (final related in json.items('relatedDocuments', RemoteJson.new)) {
      if (related.text('status') != 'ISSUED' ||
          !['SALE', 'PRESALE', 'PURCHASE'].contains(related.text('type'))) {
        continue;
      }
      final id = related.text('invoiceId');
      if (!Uuid.isValidUUID(fromString: id) || !seen.add(id)) {
        throw const FormatException('Repeated settlement document');
      }
      final result = RemoteJson(
        await _request('GET', '$_base/v2/invoices/$id'),
      );
      if (result.number('businessId') != businessId) {
        throw const FormatException('Unexpected invoice business');
      }
      final row = InvoiceSettlementDocument.fromJson(result.value['invoice']);
      _document(row);
      if (row.id != id || row.type != related.text('type')) {
        throw const FormatException('Unexpected related invoice');
      }
      docs.add(row);
    }
    final snapshot = RemoteJson(raw.value['partySnapshot']);
    return (
      detail: detail,
      documents: docs,
      anonymous: snapshot.flag('isDefault'),
    );
  }

  Future<List<InvoicePartyPayment>> payments() async {
    if (!canReadPayments) throw const AuthError(403, 'FORBIDDEN');
    final result = <InvoicePartyPayment>[],
        ids = <String>{},
        cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await _request(
          'GET',
          '$_base/v2/payments',
          query: {
            'partyType': invoice.partyType,
            'partyId': invoice.partyId,
            'limit': '100',
            'after': ?after,
          },
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected payments business');
      }
      for (final row in json.items('items', InvoicePartyPayment.fromJson)) {
        _party(row.businessId, row.partyId, row.partyType);
        if (!ids.add(row.id)) throw const FormatException('Repeated payment');
        result.add(row);
      }
      after = json.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Invalid payment cursor');
      }
    } while (after != null);
    return result;
  }

  Future<List<InvoiceSettlementSource>> sources({
    bool availableOnly = true,
  }) async {
    if (!canReadSources) throw const AuthError(403, 'FORBIDDEN');
    final result = <InvoiceSettlementSource>[],
        ids = <String>{},
        cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await _request(
          'GET',
          '$_base/sources',
          query: {
            'partyType': invoice.partyType,
            'partyId': invoice.partyId,
            if (availableOnly) 'status': 'ACTIVE',
            'limit': '100',
            'after': ?after,
          },
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected sources business');
      }
      for (final row in json.items('items', InvoiceSettlementSource.fromJson)) {
        _party(row.businessId, row.partyId, row.partyType);
        if (!ids.add(row.id) || availableOnly && row.status != 'ACTIVE') {
          throw const FormatException('Unexpected source');
        }
        if (!availableOnly ||
            row.available > 0 &&
                (row.restrictedRootId == null ||
                    row.restrictedRootId == invoice.rootId)) {
          result.add(row);
        }
      }
      after = json.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Invalid source cursor');
      }
    } while (after != null);
    return result;
  }

  Future<List<SalePaymentTarget>> targets(
    String method, {
    bool refund = false,
  }) async {
    await authorize();
    final actualDirection = refund ? refundDirection : direction;
    if ((refund ? !canRefund : !canCreate) ||
        method == 'BANK_TRANSFER' && !access.canUseBank ||
        method == 'CARD' && actualDirection == 'OUT' && !access.canUseBank) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    if (!['CASH', 'CARD', 'BANK_TRANSFER'].contains(method)) {
      throw const FormatException('Unsupported payment method');
    }
    final terminal = method == 'CARD' && actualDirection == 'IN';
    final result = <SalePaymentTarget>[],
        ids = <String>{},
        cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await _request(
          'GET',
          '$_base/treasury/options',
          query: {
            'kind': terminal ? 'terminal' : 'fund',
            'limit': '100',
            'after': ?after,
          },
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected target business');
      }
      for (final row in json.items(
        'items',
        (v) => SalePaymentTarget.fromJson(v, terminal: terminal),
      )) {
        if (!ids.add(row.id) ||
            row.branchId != null && row.branchId != branchId) {
          throw const FormatException('Unexpected target scope');
        }
        if (method == 'CASH'
            ? ['CASH', 'PETTY_CASH'].contains(row.kind)
            : terminal
            ? row.kind == 'TERMINAL'
            : row.kind == 'BANK') {
          result.add(row);
        }
      }
      after = json.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Invalid target cursor');
      }
    } while (after != null);
    return result;
  }

  Future<InvoicePaymentCommand?> restore() async {
    check();
    if (_sending != null) return pending;
    final value = await storage.read(key: _key);
    check();
    return pending = value == null
        ? null
        : InvoicePaymentCommand.fromJson(jsonDecode(value));
  }

  Future<void> send(InvoicePaymentCommand command) {
    if (_sending != null) {
      return Future.error(const AuthError(409, 'IDEMPOTENCY_CONFLICT'));
    }
    final result = _send(command);
    _sending = result;
    return result.whenComplete(() => _sending = null);
  }

  Future<void> _send(InvoicePaymentCommand command) async {
    check();
    if (_invoice == null && command.action != 'PAYMENT') {
      throw const FormatException('Direct payment requires PAYMENT action');
    }
    pending ??= await restore();
    if (pending != null && pending!.key != command.key) {
      throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    }
    await authorize();
    if (['REVERSE_PAYMENT', 'REVERSE_ALLOCATION'].contains(command.action)) {
      await _sendReversal(command);
      return;
    }
    final body = command.body;
    final refund = command.action == 'REFUND';
    final payment = command.action == 'PAYMENT' || refund;
    final actualDirection = refund ? refundDirection : direction;
    if (refund
        ? !canRefund
        : payment
        ? !canCreate
        : !canAllocate) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    if (payment) {
      _party(
        businessId,
        body['partyId'] as String,
        body['partyType'] as String,
      );
      final data = RemoteJson(body['payment']);
      final bank =
          data.text('method') == 'BANK_TRANSFER' ||
          data.text('method') == 'CARD' && actualDirection == 'OUT';
      if (bank && !access.canUseBank) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      if (data.text('direction') != actualDirection ||
          !['CASH', 'CARD', 'BANK_TRANSFER'].contains(data.text('method')) ||
          !data.flag('confirmed') ||
          data.number('amount') <= 0) {
        throw const FormatException('Invalid payment command');
      }
    } else if (pending == null) {
      final current = await invoiceDetails();
      final id = RemoteJson(body).text('invoiceId');
      if (!current.documents.any(
        (row) => row.id == id && row.status == 'ISSUED',
      )) {
        throw const FormatException(
          'Allocation is outside this invoice family',
        );
      }
      RemoteInvoiceSummary.money(body['amount']);
      if (body['amount'] == 0 ||
          !Uuid.isValidUUID(fromString: RemoteJson(body).text('sourceId'))) {
        throw const FormatException('Invalid allocation request');
      }
    }
    pending = command;
    await storage.write(key: _key, value: jsonEncode(command.toJson()));
    try {
      final json = RemoteJson(
        await _request(
          'POST',
          payment ? '$_base/v2/payments' : '$_base/settlements',
          data: body,
          key: command.key,
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected payment confirmation');
      }
      if (payment) {
        final raw = RemoteJson(json.value['payment']);
        final row = InvoicePartyPayment.fromJson(raw.value);
        _party(row.businessId, row.partyId, row.partyType);
        final expected = RemoteJson(body['payment']);
        final route = RemoteJson(expected.value['routing']);
        final actual = RemoteJson(raw.value['routing']);
        if (row.branchId != branchId ||
            row.status != 'CONFIRMED' ||
            row.direction != actualDirection ||
            row.amount != expected.number('amount') ||
            row.method != expected.text('method') ||
            raw.number('financialVersion') != 2 ||
            raw.text('purpose') != (refund ? 'REFUND' : 'SETTLEMENT')) {
          throw const FormatException('Unexpected payment confirmation');
        }
        for (final entry in route.value.entries) {
          if (actual.value[entry.key] != entry.value) {
            throw const FormatException('Unexpected payment route');
          }
        }
        for (final key in ['transactionReference', 'note']) {
          if (expected.value.containsKey(key) &&
              raw.value[key] != expected.value[key]) {
            throw const FormatException('Unexpected payment details');
          }
        }
      } else {
        final row = RemoteJson(json.value['allocation']);
        _party(
          row.number('businessId'),
          row.text('partyId'),
          row.text('partyType'),
        );
        if (!Uuid.isValidUUID(fromString: row.text('allocationId')) ||
            row.text('sourceId') != body['sourceId'] ||
            row.text('invoiceId') != body['invoiceId'] ||
            row.number('amount') != body['amount'] ||
            row.number('reversedAmount') != 0) {
          throw const FormatException('Unexpected allocation');
        }
        final doc = InvoiceSettlementDocument.fromJson(json.value['invoice']);
        _document(doc);
        if (doc.id != body['invoiceId']) {
          throw const FormatException('Unexpected allocation invoice');
        }
      }
      await storage.delete(key: _key);
      pending = null;
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

  Future<InvoicePaymentDetail> paymentDetail(String id) async {
    if (!canReadPayments) throw const AuthError(403, 'FORBIDDEN');
    if (!Uuid.isValidUUID(fromString: id)) {
      throw const FormatException('Invalid payment id');
    }
    final json = RemoteJson(await _request('GET', '$_base/v2/payments/$id'));
    final row = InvoicePaymentDetail.fromJson(json.value['item']);
    _party(row.payment.businessId, row.payment.partyId, row.payment.partyType);
    if (json.number('businessId') != businessId || row.payment.id != id) {
      throw const FormatException('Unexpected payment detail');
    }
    return row;
  }

  Future<List<InvoiceSettlementAllocation>> allocations() async {
    if (!canReadAllocations) throw const AuthError(403, 'FORBIDDEN');
    final result = <InvoiceSettlementAllocation>[],
        ids = <String>{},
        cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await _request(
          'GET',
          '$_base/allocations',
          query: {
            'partyType': invoice.partyType,
            'partyId': invoice.partyId,
            'limit': '100',
            'after': ?after,
          },
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected allocation business');
      }
      for (final row in json.items(
        'items',
        InvoiceSettlementAllocation.fromJson,
      )) {
        _party(row.businessId, row.partyId, row.partyType);
        if (!ids.add(row.id)) {
          throw const FormatException('Repeated allocation');
        }
        result.add(row);
      }
      after = json.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Invalid allocation cursor');
      }
    } while (after != null);
    return result;
  }

  Future<void> _sendReversal(InvoicePaymentCommand command) async {
    final payment = command.action == 'REVERSE_PAYMENT';
    if (payment ? !canReversePayment : !canReverseAllocation) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final body = RemoteJson(command.body);
    final reason = body.text('reason');
    if (reason.trim().isEmpty ||
        reason.length > 500 ||
        RegExp(r'[\u0000-\u0008]').hasMatch(reason)) {
      throw const FormatException('Invalid reversal reason');
    }
    InvoicePaymentDetail? original;
    InvoiceSettlementAllocation? allocation;
    if (payment) {
      original = InvoicePaymentDetail.fromJson(command.before);
      _party(
        original.payment.businessId,
        original.payment.partyId,
        original.payment.partyType,
      );
      if (!original.reversible ||
          original.payment.branchId != branchId ||
          original.payment.id != body.text('paymentId') ||
          original.revision != body.number('expectedRevision') ||
          !body.flag('fundsConfirmed')) {
        throw const FormatException('Invalid payment reversal');
      }
    } else {
      allocation = InvoiceSettlementAllocation.fromJson(command.before);
      _party(allocation.businessId, allocation.partyId, allocation.partyType);
      final amount = RemoteInvoiceSummary.money(body.value['amount']);
      if (allocation.id != body.text('allocationId') ||
          allocation.revision != body.number('expectedRevision') ||
          allocation.invoiceId == null ||
          amount == 0 ||
          amount > allocation.activeAmount) {
        throw const FormatException('Invalid allocation reversal');
      }
      if (pending == null) {
        final family = await invoiceDetails();
        if (!family.documents.any((row) => row.id == allocation!.invoiceId)) {
          throw const FormatException('Reversal outside invoice family');
        }
      }
    }
    pending = command;
    await storage.write(key: _key, value: jsonEncode(command.toJson()));
    try {
      final json = RemoteJson(
        await _request(
          'POST',
          payment ? '$_base/v2/payments/reverse' : '$_base/settlements/reverse',
          data: body.value,
          key: command.key,
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected reversal business');
      }
      if (payment) {
        final saved = InvoicePaymentDetail.fromJson(json.value['payment']);
        final reversal = InvoicePaymentDetail.fromJson(json.value['reversal']);
        for (final row in [saved, reversal]) {
          _party(
            row.payment.businessId,
            row.payment.partyId,
            row.payment.partyType,
          );
        }
        if (saved.payment.id != original!.payment.id ||
            saved.payment.status != 'REVERSED' ||
            saved.revision <= original.revision ||
            saved.json['reversedByPaymentId'] != reversal.payment.id ||
            reversal.json['originalPaymentId'] != original.payment.id ||
            reversal.payment.id == original.payment.id ||
            reversal.payment.amount != original.payment.amount ||
            saved.financialVersion != 2 ||
            saved.routing?['fundId'] != original.routing?['fundId'] ||
            saved.routing?['terminalId'] != original.routing?['terminalId'] ||
            saved.payment.amount != original.payment.amount ||
            saved.payment.method != original.payment.method ||
            saved.payment.direction != original.payment.direction ||
            reversal.payment.status != 'CONFIRMED' ||
            reversal.purpose != 'REVERSAL' ||
            reversal.payment.branchId != branchId ||
            saved.payment.branchId != branchId ||
            reversal.payment.direction !=
                (original.payment.direction == 'IN' ? 'OUT' : 'IN') ||
            reversal.payment.method != original.payment.method ||
            reversal.financialVersion != 2 ||
            reversal.note != reason ||
            reversal.routing?['fundId'] != original.routing?['fundId'] ||
            reversal.routing?['terminalId'] !=
                original.routing?['terminalId']) {
          throw const FormatException(
            'Unexpected payment reversal confirmation',
          );
        }
      } else {
        final saved = InvoiceSettlementAllocation.fromJson(
          json.value['allocation'],
        );
        _party(saved.businessId, saved.partyId, saved.partyType);
        final doc = InvoiceSettlementDocument.fromJson(json.value['invoice']);
        _document(doc);
        if (saved.id != allocation!.id ||
            saved.sourceId != allocation.sourceId ||
            saved.invoiceId != allocation.invoiceId ||
            saved.revision <= allocation.revision ||
            saved.amount != allocation.amount ||
            saved.reason != reason ||
            saved.reversedAmount !=
                allocation.reversedAmount + body.number('amount') ||
            doc.id != allocation.invoiceId) {
          throw const FormatException(
            'Unexpected allocation reversal confirmation',
          );
        }
      }
      await storage.delete(key: _key);
      pending = null;
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
      return 'اطلاعات دریافت‌وپرداخت یا پاسخ سرور معتبر نیست؛ نتیجهٔ درخواست قبلی را پیگیری کنید.';
    }
    if (failure is AuthError) {
      switch (failure.code) {
        case 'REVISION_CONFLICT':
          return 'اطلاعات پرداخت یا تخصیص تغییر کرده است؛ جزئیات را دوباره دریافت کنید.';
        case 'CREDIT_SALES_DISABLED':
          return 'این اصلاح بدهی مشتری را باز می‌کند؛ فروش اعتباری کسب‌وکار غیرفعال است.';
        case 'RECORD_IN_USE':
          return 'وجه دارای تعهد، پیش‌دریافت یا تسویهٔ در جریان است؛ ابتدا آن مورد را تعیین تکلیف کنید.';
        case 'FORBIDDEN':
          return 'مجوز ثبت وجه، استفاده از حساب یا تخصیص اعتبار را ندارید.';
        case 'INSUFFICIENT_CREDIT':
          return 'اعتبار آزاد طرف حساب برای برگشت این مبلغ کافی نیست؛ اطلاعات را تازه کنید.';
        case 'INSUFFICIENT_FUNDS':
          return 'موجودی قابل استفادهٔ حساب یا صندوق برای پرداخت کافی نیست.';
        case 'SETTLEMENT_EXCEEDED':
          return 'مبلغ تخصیص از اعتبار قابل استفاده یا بدهی سند بیشتر است؛ اطلاعات را تازه کنید.';
        case 'INVALID_STATE':
          return 'وضعیت سند یا صندوق اجازهٔ عملیات نمی‌دهد؛ فعال‌بودن حساب و بازبودن شیفت صندوق را بررسی کنید.';
        case 'DEFAULT_CUSTOMER_CREDIT_FORBIDDEN':
          return 'ثبت وجه مستقل برای مشتری پیش‌فرض مجاز نیست؛ پرداخت باید در جریان خود فاکتور انجام شود.';
        case 'FISCAL_PERIOD_CLOSED':
          return 'دورهٔ مالی بسته است؛ ثبت مالی انجام نشد.';
        case 'FISCAL_YEAR_REQUIRED':
          return 'سال مالی متناسب با تاریخ ثبت تعریف نشده است.';
        case 'VALIDATION_FAILED':
          return 'مبلغ، روش، حساب و تایید جابه‌جایی واقعی وجه را بررسی کنید.';
        case 'SELECTION_CHANGED':
          return 'نشست یا شعبه تغییر کرده است؛ صفحه را دوباره باز کنید.';
        case 'IDEMPOTENCY_CONFLICT':
          return 'درخواست قبلی مشخص نیست؛ همان درخواست را پیگیری کنید.';
      }
      if (!failure.requiresLogin && failure.statusCode < 500) {
        return 'عملیات انجام نشد؛ کد خطای سرور: ${failure.code}';
      }
    }
    return API.loginError(failure);
  }
}
