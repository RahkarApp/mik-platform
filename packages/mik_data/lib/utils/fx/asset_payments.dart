import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/fixed_asset.dart';
import '../../source/remote/models/financial_report.dart';
import '../../source/remote/models/remote_json.dart';
import 'fixed_assets.dart';
import 'sale_invoice.dart';
import 'financial_reports.dart';

class AssetPaymentCommand {
  final String action, key, _body, _before;
  bool attempted;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  Map<String, dynamic> get before =>
      jsonDecode(_before) as Map<String, dynamic>;
  AssetPaymentCommand(
    this.action,
    Map<String, dynamic> body, {
    required Map<String, dynamic> before,
  }) : key = const Uuid().v4(),
       _body = jsonEncode(body),
       _before = jsonEncode(before),
       attempted = false;
  AssetPaymentCommand.fromJson(Object? value) : this._(RemoteJson(value));
  AssetPaymentCommand._(RemoteJson row)
    : action = row.text('action'),
      key = row.text('key'),
      _body = jsonEncode(RemoteJson(row.value['body']).value),
      _before = jsonEncode(RemoteJson(row.value['before']).value),
      attempted = row.flag('attempted') {
    FinancialReportPage.uuid(key);
    if (!AssetPaymentsFX.paths.containsKey(action)) {
      throw const FormatException('Invalid saved asset payment');
    }
  }
  Map<String, dynamic> toJson() => {
    'action': action,
    'key': key,
    'body': body,
    'before': before,
    'attempted': attempted,
  };
}

class AssetPaymentsFX {
  final FixedAssetsFX assets;
  final String assetId;
  final FlutterSecureStorage storage;
  AssetPaymentCommand? pending;
  bool sending = false;
  AssetPaymentsFX(
    this.assets,
    this.assetId, {
    this.storage = const FlutterSecureStorage(),
  });
  static const paths = {
    'payment': 'assets/payments',
    'reverse': 'assets/payments/reverse',
    'cheque': 'assets/cheques/status',
  };
  bool has(String permission) => assets.access.has(permission);
  bool can(String action) =>
      has(
        action == 'payment'
            ? 'accounting.asset.payment.pay'
            : action == 'reverse'
            ? 'accounting.asset.payment.reverse'
            : 'accounting.cheque.clear',
      ) &&
      (action == 'payment' || has('accounting.asset.payment.pay'));
  Future<void> authorize() => assets.authorize();
  String get _key =>
      'asset-payments.v1.${assets.context.auth.appId}.${assets.context.origin}.${assets.context.session.identityId}.${assets.access.businessId}.${assets.branchId}.$assetId';
  Future<RemoteJson> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? data,
    String? key,
  }) async {
    assets.check();
    final row = RemoteJson(
      await assets.context.auth.request(
        method,
        '/v1/businesses/${assets.access.businessId}/accounting/$path',
        branchId: assets.branchId,
        query: query,
        data: data,
        idempotencyKey: key,
      ),
    );
    assets.check();
    if (row.number('businessId') != assets.access.businessId) {
      throw const FormatException('Unexpected asset payment business');
    }
    return row;
  }

  void _asset(RemoteFixedAsset row) {
    if (row.id != assetId ||
        row.businessId != assets.access.businessId ||
        row.branchId != assets.branchId ||
        row.uncoveredAmount < 0 ||
        row.json['source'] == 'PURCHASE' &&
            row.status != 'CANCELLED' &&
            row.json['liabilityAmount'] !=
                row.money('acquisitionCost') - row.money('paidAmount')) {
      throw const FormatException('Unexpected asset payment balance');
    }
  }

  AssetPayment _payment(Object? value, RemoteFixedAsset parent) {
    final row = AssetPayment(value);
    if (row.businessId != assets.access.businessId ||
        row.assetId != assetId ||
        row.branchId != assets.branchId ||
        row.supplierId != parent.json['supplierId']) {
      throw const FormatException('Unexpected asset payment scope');
    }
    return row;
  }

  Future<List<AssetPayment>> payments(RemoteFixedAsset asset) async {
    await authorize();
    _asset(asset);
    final rows = <AssetPayment>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final page = await _request(
        'GET',
        'assets/payments',
        query: {'fixedAssetId': assetId, 'limit': '100', 'after': ?after},
      );
      final items = page.items('items', (v) => _payment(v, asset));
      for (final row in items) {
        if (!ids.add(row.id)) {
          throw const FormatException('Repeated asset payment');
        }
        rows.add(row);
      }
      final next = page.optionalText('nextCursor');
      if (next != null) {
        FinancialReportPage.uuid(next);
        if (items.isEmpty || next != items.last.id || !cursors.add(next)) {
          throw const FormatException('Invalid asset payment cursor');
        }
      }
      after = next;
    } while (after != null);
    return rows;
  }

  Future<List<SalePaymentTarget>> targets(String method) async {
    await authorize();
    if (!['CASH', 'BANK_TRANSFER', 'CHEQUE'].contains(method)) {
      throw const FormatException('Unsupported asset payment method');
    }
    if (!has('accounting.treasury.use') ||
        method != 'CASH' && !assets.access.canUseBank) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final rows = <SalePaymentTarget>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final page = await _request(
        'GET',
        'treasury/options',
        query: {'kind': 'fund', 'limit': '100', 'after': ?after},
      );
      final items = page.items(
        'items',
        (v) => SalePaymentTarget.fromJson(v, terminal: false),
      );
      for (final row in items) {
        if (!ids.add(row.id) ||
            row.branchId != null && row.branchId != assets.branchId) {
          throw const FormatException('Unexpected asset fund');
        }
        if (method == 'CASH'
            ? ['CASH', 'PETTY_CASH'].contains(row.kind)
            : row.kind == 'BANK') {
          rows.add(row);
        }
      }
      final next = page.optionalText('nextCursor');
      if (next != null) {
        FinancialReportPage.uuid(next);
        if (items.isEmpty || next != items.last.id || !cursors.add(next)) {
          throw const FormatException('Invalid asset fund cursor');
        }
      }
      after = next;
    } while (after != null);
    return rows;
  }

  Future<AssetPaymentCommand?> restore() async {
    assets.check();
    if (sending) return pending;
    return _restore();
  }

  Future<AssetPaymentCommand?> _restore() async {
    final saved = await storage.read(key: _key);
    assets.check();
    return pending = saved == null
        ? null
        : AssetPaymentCommand.fromJson(jsonDecode(saved));
  }

  Future<void> send(AssetPaymentCommand command) async {
    if (sending) throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    sending = true;
    try {
      await _restore();
      if (pending != null && pending!.key != command.key) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      await authorize();
      if (!can(command.action) || !paths.containsKey(command.action)) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      final parent = RemoteFixedAsset(command.before['asset']);
      _asset(parent);
      final body = RemoteJson(command.body);
      AssetPayment? old;
      if (command.action == 'payment') {
        final pay = RemoteJson(body.value['payment']);
        if (body.text('fixedAssetId') != assetId ||
            body.number('expectedRevision') != parent.revision ||
            parent.json['source'] != 'PURCHASE' ||
            parent.status == 'CANCELLED' ||
            !['CASH', 'BANK_TRANSFER', 'CHEQUE'].contains(pay.text('method')) ||
            FinancialReportPage.money(pay.value['amount'], nonnegative: true) <=
                0 ||
            pay.number('amount') > parent.uncoveredAmount ||
            pay.text('method') != 'CHEQUE' && pay.value['confirmed'] != true) {
          throw const FormatException('Invalid asset payment command');
        }
        if (pay.text('method') == 'CHEQUE' &&
            !has('accounting.expense.cheque.pay')) {
          throw const AuthError(403, 'FORBIDDEN');
        }
      } else {
        old = _payment(command.before['payment'], parent);
        if (body.text('assetPaymentId') != old.id ||
            body.number('expectedRevision') != old.revision ||
            body.text('reason').trim().isEmpty ||
            (command.action == 'reverse'
                ? old.status != 'CONFIRMED' ||
                      body.value['fundsConfirmed'] != true
                : old.method != 'CHEQUE' ||
                      old.status != 'PENDING' ||
                      body.value['confirmed'] != true ||
                      ![
                        'CONFIRMED',
                        'BOUNCED',
                        'RETURNED',
                      ].contains(body.text('status')))) {
          throw const FormatException('Invalid asset payment correction');
        }
      }
      final previous = command.attempted;
      pending = command;
      command.attempted = true;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      try {
        final response = await _request(
          'POST',
          paths[command.action]!,
          data: command.body,
          key: command.key,
        );
        final asset = RemoteFixedAsset(response.value['asset']);
        _asset(asset);
        final row = _payment(response.value['payment'], asset);
        if (asset.revision <= parent.revision ||
            asset.json['supplierId'] != parent.json['supplierId']) {
          throw const FormatException('Unexpected asset payment result');
        }
        if (old != null) {
          if (row.id != old.id ||
              row.revision <= old.revision ||
              row.amount != old.amount ||
              row.method != old.method ||
              row.fundId != old.fundId ||
              row.status !=
                  (command.action == 'reverse'
                      ? 'REVERSED'
                      : body.text('status'))) {
            throw const FormatException('Unexpected payment correction');
          }
        } else {
          final input = RemoteJson(body.value['payment']);
          if (row.method != input.text('method') ||
              row.amount != input.number('amount') ||
              row.fundId != RemoteJson(input.value['routing']).text('fundId') ||
              row.status !=
                  (row.method == 'CHEQUE' ? 'PENDING' : 'CONFIRMED')) {
            throw const FormatException('Payment not confirmed');
          }
          if (row.method == 'CHEQUE') {
            final sent = RemoteJson(input.value['cheque']),
                saved = RemoteJson(row.json['cheque']);
            for (final key in ['bankName', 'number', 'sayadId', 'drawerName']) {
              if (saved.value[key] != sent.value[key]) {
                throw const FormatException('Unexpected saved cheque');
              }
            }
            if (DateTime.parse(sent.text('dueAt')) !=
                DateTime.parse(saved.text('dueAt'))) {
              throw const FormatException('Unexpected cheque due date');
            }
          }
        }
        await storage.delete(key: _key);
        pending = null;
      } on AuthError catch (error) {
        if (!previous &&
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
      sending = false;
    }
  }

  static String message(Object failure) {
    if (failure is FormatException) {
      return 'اطلاعات پرداخت دارایی معتبر نیست؛ اطلاعات را دوباره دریافت کنید. درخواست تعیین‌تکلیف‌نشده را پیگیری کنید.';
    }
    if (failure is AuthError) {
      if (failure.code == 'FORBIDDEN') {
        return 'مجوز مشاهده یا تغییر پرداخت دارایی، استفاده از صندوق یا حساب بانکی را ندارید.';
      }
      if (failure.code == 'DUPLICATE_RECORD') {
        return 'رکورد تکراری است؛ مشخصات و شناسه صیاد چک را بررسی کنید.';
      }
      if (failure.code == 'SETTLEMENT_EXCEEDED') {
        return 'مبلغ از مانده بدون پرداخت و چک در انتظار بیشتر است؛ اطلاعات را تازه کنید.';
      }
      if (failure.code == 'IDEMPOTENCY_CONFLICT') {
        return 'درخواست قبلی پرداخت دارایی را پیگیری کنید.';
      }
      if (failure.code == 'REVISION_CONFLICT') {
        return 'اطلاعات دارایی یا پرداخت تغییر کرده است؛ آن را تازه کنید.';
      }
    }
    return FinancialReportsFX.message(failure);
  }
}
