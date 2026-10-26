import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/business_sms.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/business_sms.dart';
import 'package:mik_data/utils/fx/sms_funding.dart';

import 'business_sms_test.dart' as fixture;
import 'support/onboarding_fixtures.dart';

const paymentId = '66666666-6666-4666-8666-666666666666';
Map<String, Object?> paymentRow({
  String status = 'PENDING',
  String fulfillment = 'WAITING',
  int businessId = 12345678,
}) => {
  'paymentId': paymentId,
  'platformId': 'mik',
  'businessId': businessId,
  'purpose': 'SMS_TOPUP',
  'subjectId': fixture.templateId,
  'amount': 1000,
  'currency': 'TOMAN',
  'beneficiary': 'PLATFORM',
  'gatewayAccountId': warehouse,
  'gatewayOwnership': 'PLATFORM',
  'provider': 'zarinpal',
  'status': status,
  'fulfillmentStatus': fulfillment,
  'paymentUrl': 'https://www.zarinpal.com/pg/StartPay/ABCDEFGHIJKLMNOPQRST',
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
  'revision': 2,
  if (status == 'PAID') ...{
    'paidAt': DateTime.now().toUtc().toIso8601String(),
    'referenceNo': '123456789',
  },
};
Map<String, Object?> accountRow({String kind = 'SMS'}) => {
  'accountId': warehouse,
  'platformId': 'mik',
  'businessId': 12345678,
  'kind': kind,
  'balance': 5000,
  'held': 1000,
  'available': 4000,
  'currency': 'TOMAN',
  'revision': 2,
};
http.Response grants(http.Request r, {bool allowed = true}) {
  final row = jsonDecode(fixture.grants(r).body) as Map<String, dynamic>;
  if (allowed) {
    (row['permissionCodes'] as List).addAll([
      'notification.notification.balance.transfer',
      'payment.payment.create',
      'payment.payment.read',
    ]);
  }
  return jsonResponse(row);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(fixture.resetStorage);
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app uncertain transfer restores the original key and amount without fabricating a balance delta',
      () async {
        final writes = <http.Request>[];
        var lost = true;
        final context = fixture.activate(app, (r) async {
          if (r.url.path.endsWith('/authorization')) return grants(r);
          writes.add(r);
          expect(r.url.path, '/v1/businesses/12345678/sms/wallet/transfers');
          expect(r.headers['x-app-id'], app);
          expect(jsonDecode(r.body), {'amount': 1000});
          if (lost) {
            lost = false;
            throw TimeoutException('lost transfer reply');
          }
          return jsonResponse({
            'operationId': fixture.templateId,
            'account': accountRow(),
            'replayed': true,
          });
        });
        final first = SmsFundingFX(BusinessSmsFX(context));
        await expectLater(
          first.send(SmsFundingCommand('TRANSFER', {'amount': 1000})),
          throwsA(anything),
        );
        final restored = SmsFundingFX(BusinessSmsFX(context));
        final command = (await restored.restore())!;
        final result = await restored.send(command) as SmsWallet;
        expect(result.available, 4000);
        expect(
          writes.first.headers['idempotency-key'],
          writes.last.headers['idempotency-key'],
        );
        expect(await restored.restore(), isNull);
      },
    );
  }
  test('known payment uses GET until PAID and APPLIED; a bank return or PAID alone never confirms credit', () async {
    final writes = <http.Request>[];
    var status = 'PENDING', fulfillment = 'WAITING';
    final fx = SmsFundingFX(
      BusinessSmsFX(
        fixture.activate('mik', (r) async {
          if (r.url.path.endsWith('/authorization')) return grants(r);
          writes.add(r);
          return jsonResponse({
            'payment': paymentRow(status: status, fulfillment: fulfillment),
            if (r.method == 'POST') 'replayed': false,
          });
        }),
      ),
    );
    final command = SmsFundingCommand('TOPUP', {
      'purpose': 'SMS_TOPUP',
      'amount': 1000,
      'returnUrl': 'https://app.example.com/pay',
    });
    expect((await fx.send(command) as SmsTopupPayment).applied, isFalse);
    expect((await fx.restore())!.paymentId, paymentId);
    status = 'PAID';
    fulfillment = 'PENDING';
    expect((await fx.send(fx.pending!) as SmsTopupPayment).applied, isFalse);
    expect(await fx.restore(), isNotNull);
    fulfillment = 'APPLIED';
    expect((await fx.send(fx.pending!) as SmsTopupPayment).applied, isTrue);
    expect(await fx.restore(), isNull);
    expect(writes.map((r) => r.method), ['POST', 'GET', 'GET']);
    expect(writes.first.url.path, '/v1/businesses/12345678/payments');
  });
  test('foreign receipts, untrusted bank links and invalid funding input are rejected', () {
    expect(
      () => SmsTopupPayment(paymentRow(businessId: 87654321), 12345678),
      throwsFormatException,
    );
    expect(
      () => SmsTopupPayment({
        ...paymentRow(),
        'paymentUrl': 'https://example.com/pg/StartPay/ABCDEFGHIJKLMNOPQRST',
      }, 12345678),
      throwsFormatException,
    );
    expect(
      () => SmsFundingFX.validate(SmsFundingCommand('TRANSFER', {'amount': 0})),
      throwsA(isA<AuthError>()),
    );
    expect(
      () => SmsFundingFX.validate(
        SmsFundingCommand('TOPUP', {
          'purpose': 'SMS_TOPUP',
          'amount': 1000,
          'returnUrl': 'mik://pay',
        }),
      ),
      throwsA(isA<AuthError>()),
    );
  });
  test('missing transfer permission blocks POST', () async {
    final writes = <http.Request>[];
    final fx = SmsFundingFX(
      BusinessSmsFX(
        fixture.activate('mik', (r) async {
          if (r.url.path.endsWith('/authorization')) {
            return grants(r, allowed: false);
          }
          writes.add(r);
          return jsonResponse({});
        }),
      ),
    );
    await expectLater(
      fx.send(SmsFundingCommand('TRANSFER', {'amount': 1000})),
      throwsA(isA<AuthError>().having((e) => e.code, 'code', 'FORBIDDEN')),
    );
    expect(writes, isEmpty);
  });
}
