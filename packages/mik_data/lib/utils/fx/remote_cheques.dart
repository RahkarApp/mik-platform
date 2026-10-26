import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/api.dart';
import '../../source/remote/models/remote_cheque.dart';
import '../../source/remote/models/invoice_payment.dart';
import '../../source/remote/models/invoice_read.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';
import 'treasury.dart';

class ChequeCommand {
  final String key, action, _body;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  final String? _before;
  Map<String, dynamic>? get before =>
      _before == null ? null : jsonDecode(_before) as Map<String, dynamic>;
  ChequeCommand(
    this.action,
    Map<String, dynamic> body, {
    Map<String, dynamic>? before,
  }) : key = const Uuid().v4(),
       _body = jsonEncode(body),
       _before = before == null ? null : jsonEncode(before);
  ChequeCommand.fromJson(Object? value) : this._(RemoteJson(value));
  ChequeCommand._(RemoteJson data)
    : key = data.text('key'),
      action = data.text('action'),
      _body = jsonEncode(RemoteJson(data.value['body']).value),
      _before = data.value['before'] == null
          ? null
          : jsonEncode(RemoteJson(data.value['before']).value) {
    if (!Uuid.isValidUUID(fromString: key) ||
        !['CREATE', 'STATUS'].contains(action)) {
      throw const FormatException('Invalid cheque command');
    }
  }
  Map<String, Object?> toJson() => {
    'key': key,
    'action': action,
    'body': body,
    'before': before,
  };
}

class RemoteChequesFX {
  final BusinessContext context;
  final RemoteInvoiceSummary? invoice;
  final FlutterSecureStorage storage;
  final String branchId;
  late final access = TreasuryFX.forContext(context, branchId);
  ChequeCommand? pending;
  bool _sending = false;
  RemoteChequesFX(
    this.context, {
    this.invoice,
    this.storage = const FlutterSecureStorage(),
  }) : branchId = context.selectedBranch?.branchId ?? '';
  int get businessId => context.session.business.businessId;
  String get base => '/v1/businesses/$businessId/accounting';
  String get _key =>
      'cheques.v2.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId.${invoice?.partyId ?? 'all'}';
  void check() {
    context.check();
    if (branchId.isEmpty || context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<void> authorize() async {
    check();
    await access.authorize();
    check();
  }

  bool get canRead => access.has('accounting.cheque.read', business: true);
  bool canCreate(String type) =>
      access.has('accounting.payment.create', business: true) &&
      access.has('accounting.payment.allocate') &&
      access.has('accounting.treasury.use') &&
      access.canUseBank &&
      access.has(
        type == 'CUSTOMER'
            ? 'accounting.sale.cheque.receive'
            : 'accounting.purchase.cheque.pay',
      );
  bool get canClear =>
      access.has('accounting.cheque.clear') &&
      access.has('accounting.payment.create', business: true) &&
      access.has('accounting.payment.read', business: true) &&
      access.has('accounting.treasury.use') &&
      access.canUseBank;
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

  RemoteCheque parse(Object? value) {
    final row = RemoteCheque.fromJson(value);
    if (row.businessId != businessId) {
      throw const FormatException('Unexpected cheque business');
    }
    return row;
  }

  Future<List<RemoteCheque>> all() async {
    if (!canRead) throw const AuthError(403, 'FORBIDDEN');
    final result = <RemoteCheque>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await request(
          'GET',
          '$base/cheques',
          query: {
            'limit': '100',
            'after': ?after,
            if (invoice != null) ...{
              'partyId': invoice!.partyId,
              'partyType': invoice!.partyType,
            },
          },
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected cheque list business');
      }
      for (final row in json.items('items', parse)) {
        if (!ids.add(row.id) ||
            invoice != null &&
                (row.partyId != invoice!.partyId ||
                    row.partyType != invoice!.partyType)) {
          throw const FormatException('Unexpected cheque list');
        }
        result.add(row);
      }
      after = json.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Invalid cheque cursor');
      }
    } while (after != null);
    return result;
  }

  Future<RemoteCheque> get(String id) async {
    if (!canRead) throw const AuthError(403, 'FORBIDDEN');
    final json = RemoteJson(
      await request('GET', '$base/cheques/${Uri.encodeComponent(id)}'),
    );
    final row = parse(json.value['item']);
    if (json.number('businessId') != businessId ||
        row.id != id ||
        invoice != null &&
            (row.partyId != invoice!.partyId ||
                row.partyType != invoice!.partyType)) {
      throw const FormatException('Unexpected cheque detail');
    }
    return row;
  }

  Future<InvoicePaymentDetail> payment(RemoteCheque cheque) async {
    if (!access.has('accounting.payment.read', business: true)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final json = RemoteJson(
      await request('GET', '$base/v2/payments/${cheque.paymentId}'),
    );
    final row = InvoicePaymentDetail.fromJson(json.value['item']);
    if (json.number('businessId') != businessId ||
        row.payment.businessId != businessId ||
        row.payment.id != cheque.paymentId ||
        row.payment.partyId != cheque.partyId ||
        row.payment.partyType != cheque.partyType ||
        row.payment.branchId != cheque.branchId ||
        row.payment.amount != cheque.amount ||
        row.payment.direction != cheque.direction ||
        row.payment.method != 'CHEQUE' ||
        row.json['chequeId'] != cheque.id) {
      throw const FormatException('Unexpected cheque payment');
    }
    return row;
  }

  Future<List<({String id, String name})>> banks() async {
    if (!access.has('accounting.treasury.use') || !access.canUseBank) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final rows = <({String id, String name})>[],
        ids = <String>{},
        cursors = <String>{};
    String? after;
    do {
      final json = RemoteJson(
        await request(
          'GET',
          '$base/treasury/options',
          query: {'kind': 'fund', 'limit': '100', 'after': ?after},
        ),
      );
      if (json.number('businessId') != businessId) {
        throw const FormatException('Unexpected bank options');
      }
      for (final item in json.items('items', RemoteJson.new)) {
        final id = item.text('fundId');
        if (!Uuid.isValidUUID(fromString: id) || !ids.add(id)) {
          throw const FormatException('Invalid bank option');
        }
        if (item.text('kind') == 'BANK' &&
            item.optionalText('branchId') == null) {
          rows.add((id: id, name: item.text('name')));
        }
      }
      after = json.optionalText('nextCursor');
      if (after != null && !cursors.add(after)) {
        throw const FormatException('Repeated bank cursor');
      }
    } while (after != null);
    return rows;
  }

  Future<ChequeCommand?> _saved() async {
    final value = await storage.read(key: _key);
    check();
    return pending = value == null
        ? null
        : ChequeCommand.fromJson(jsonDecode(value));
  }

  Future<ChequeCommand?> restore() async {
    check();
    if (_sending) return pending;
    return _saved();
  }

  Future<RemoteCheque> send(ChequeCommand command) async {
    if (_sending) throw const AuthError(409, 'CHEQUE_PENDING');
    _sending = true;
    try {
      pending ??= await _saved();
      if (pending != null && pending!.key != command.key) {
        throw const AuthError(409, 'CHEQUE_PENDING');
      }
      await authorize();
      final body = RemoteJson(command.body);
      final create = command.action == 'CREATE';
      RemoteCheque? before;
      InvoicePaymentDetail? beforePayment;
      if (create) {
        if (!canCreate(body.text('partyType'))) {
          throw const AuthError(403, 'FORBIDDEN');
        }
        if (!['CUSTOMER', 'SUPPLIER'].contains(body.text('partyType')) ||
            !Uuid.isValidUUID(fromString: body.text('partyId'))) {
          throw const FormatException('Invalid cheque party');
        }
        final details = RemoteJson(body.value['payment']);
        if (details.text('method') != 'CHEQUE' ||
            details.text('direction') !=
                (body.text('partyType') == 'CUSTOMER' ? 'IN' : 'OUT')) {
          throw const FormatException('Invalid cheque direction');
        }
      } else {
        if (!canClear) throw const AuthError(403, 'FORBIDDEN');
        final snapshot = RemoteJson(command.before);
        before = parse(snapshot.value['cheque']);
        beforePayment = InvoicePaymentDetail.fromJson(
          snapshot.value['payment'],
        );
        if (before.branchId != branchId ||
            before.status != 'PENDING' ||
            before.id != body.text('chequeId') ||
            before.revision != body.number('expectedRevision') ||
            !body.flag('confirmed') ||
            ![
              'CONFIRMED',
              'BOUNCED',
              'RETURNED',
            ].contains(body.text('status')) ||
            beforePayment.payment.id != before.paymentId ||
            beforePayment.routing != null &&
                body.value.containsKey('routing')) {
          throw const FormatException('Invalid cheque status request');
        }
      }
      pending = command;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      check();
      try {
        final json = RemoteJson(
          await request(
            'POST',
            create ? '$base/v2/payments' : '$base/v2/cheques/status',
            data: body.value,
            key: command.key,
          ),
        );
        if (json.number('businessId') != businessId) {
          throw const FormatException('Unexpected cheque confirmation');
        }
        final savedPayment = InvoicePaymentDetail.fromJson(
          json.value['payment'],
        );
        final row = create
            ? await get(RemoteJson(json.value['payment']).text('chequeId'))
            : parse(json.value['cheque']);
        if (row.branchId != branchId ||
            savedPayment.payment.businessId != businessId ||
            savedPayment.payment.branchId != branchId ||
            savedPayment.payment.id != row.paymentId ||
            savedPayment.json['chequeId'] != row.id ||
            savedPayment.payment.partyId != row.partyId ||
            savedPayment.payment.partyType != row.partyType ||
            savedPayment.payment.method != 'CHEQUE' ||
            savedPayment.payment.amount != row.amount ||
            savedPayment.payment.direction != row.direction ||
            savedPayment.payment.status != row.status ||
            savedPayment.financialVersion != 2) {
          throw const FormatException('Unexpected cheque/payment confirmation');
        }
        if (create) {
          final details = RemoteJson(body.value['payment']);
          final data = RemoteJson(details.value['cheque']);
          if (row.partyId != body.text('partyId') ||
              row.partyType != body.text('partyType') ||
              row.status != 'PENDING' ||
              row.amount != details.number('amount') ||
              row.direction != details.text('direction') ||
              savedPayment.purpose != 'SETTLEMENT' ||
              savedPayment.routing?['fundId'] !=
                  RemoteJson(details.value['routing']).text('fundId')) {
            throw const FormatException('Unexpected saved cheque');
          }
          for (final entry in data.value.entries) {
            if (entry.key == 'dueAt'
                ? row.dueAt != DateTime.parse(entry.value as String)
                : row.json[entry.key] != entry.value) {
              throw const FormatException('Unexpected cheque fields');
            }
          }
        } else {
          final fund =
              beforePayment!.routing?['fundId'] ??
              RemoteJson(body.value['routing']).text('fundId');
          if (row.id != before!.id ||
              row.paymentId != before.paymentId ||
              row.partyId != before.partyId ||
              row.partyType != before.partyType ||
              row.amount != before.amount ||
              row.direction != before.direction ||
              row.revision <= before.revision ||
              row.status != body.text('status') ||
              savedPayment.routing?['fundId'] != fund ||
              savedPayment.note != body.text('reason') ||
              savedPayment.purpose != beforePayment.purpose) {
            throw const FormatException(
              'Unexpected cheque status confirmation',
            );
          }
        }
        await storage.delete(key: _key);
        pending = null;
        return row;
      } on AuthError catch (error) {
        if (error.statusCode < 500 &&
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
    if (error is FormatException) {
      return 'اطلاعات چک یا پاسخ سرور معتبر نیست؛ درخواست قبلی را پیگیری کنید.';
    }
    if (error is AuthError) {
      switch (error.code) {
        case 'FORBIDDEN':
          return 'مجوز مشاهده، ثبت چک، تعیین نتیجه یا استفاده از حساب بانکی را ندارید.';
        case 'REVISION_CONFLICT':
          return 'اطلاعات چک تغییر کرده است؛ جزئیات جدید را دریافت کنید.';
        case 'DUPLICATE_RECORD':
          return 'این شناسهٔ صیادی قبلاً در کسب‌وکار ثبت شده است.';
        case 'INVALID_STATE':
          return 'فقط چک در انتظار قابل تعیین نتیجه است؛ چک نهایی نیازمند اصلاح مالی جداگانه است.';
        case 'CHEQUE_PENDING':
          return 'درخواست قبلی مشخص نیست؛ همان درخواست را پیگیری کنید.';
        case 'DEFAULT_CUSTOMER_CREDIT_FORBIDDEN':
          return 'چک برای مشتری پیش‌فرض مجاز نیست؛ مشتری مشخص انتخاب کنید.';
        case 'INSUFFICIENT_FUNDS':
          return 'ماندهٔ حساب بانکی برای پرداخت چک کافی نیست.';
        case 'VALIDATION_FAILED':
          return 'مبلغ، مشخصات چک، سررسید و تایید نتیجهٔ واقعی را بررسی کنید.';
        case 'SELECTION_CHANGED':
          return 'نشست یا شعبه تغییر کرده است؛ صفحه را دوباره باز کنید.';
      }
      if (!error.requiresLogin && error.statusCode < 500) {
        return 'عملیات چک انجام نشد؛ کد خطای سرور: ${error.code}';
      }
    }
    return API.loginError(error);
  }
}
