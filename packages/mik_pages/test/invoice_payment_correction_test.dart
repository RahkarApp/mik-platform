import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/invoice_payment.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/invoice_payment.dart';
import 'package:mik_pages/invoice/payment_screen.dart';
import 'package:mik_pages/invoice/payment_correction_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'invoice_payment_test.dart' as original;
import 'invoice_read_test.dart' show invoiceOne;

const reversalId = '11111111-1111-4111-8111-111111111117';

class CorrectionServer extends original.PaymentServer {
  CorrectionServer(super.app, {super.type});
  final allocations = <Map<String, dynamic>>[];
  bool reverseAllowed = true,
      credit = true,
      wrongReversal = false,
      foreign = false;
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final reply = await super.respond(request);
      final json = jsonDecode(reply.body) as Map<String, dynamic>;
      (json['permissionCodes'] as List).addAll([
        if (request.url.queryParameters['scopeType'] == 'BUSINESS') ...[
          'accounting.payment.allocate',
          if (reverseAllowed) 'accounting.payment.reverse',
        ] else if (credit)
          'accounting.sale.credit',
      ]);
      return jsonResponse(json);
    }
    if (request.method == 'GET' && path.contains('/v2/payments/')) {
      requests.add(request);
      final row = paymentRows.firstWhere(
        (r) => path.endsWith(r['paymentId'] as String),
      );
      return jsonResponse({
        'businessId': 12345678,
        'item': {...row, if (foreign) 'partyId': invoiceOne},
      });
    }
    if (request.method == 'GET' && path.endsWith('/allocations')) {
      requests.add(request);
      expect(request.headers['x-branch-id'], branch);
      return jsonResponse({
        'businessId': 12345678,
        'items': allocations
            .map((r) => {...r, if (foreign) 'partyId': invoiceOne})
            .toList(),
        'nextCursor': null,
      });
    }
    if (request.method == 'GET' && path.endsWith('/sources')) {
      requests.add(request);
      return jsonResponse({
        'businessId': 12345678,
        'items': sourceRows
            .where(
              (r) =>
                  request.url.queryParameters['status'] == null ||
                  r['status'] == request.url.queryParameters['status'],
            )
            .toList(),
        'nextCursor': null,
      });
    }
    if (request.method == 'POST' && path.endsWith('/reverse')) {
      requests.add(request);
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!;
      if (receipts.containsKey(key)) return jsonResponse(receipts[key]!);
      final data = jsonDecode(request.body) as Map<String, dynamic>;
      if (type == 'SALE' && !credit) {
        return jsonResponse({
          'error': {'code': 'CREDIT_SALES_DISABLED'},
        }, 409);
      }
      late Map<String, dynamic> result;
      if (path.endsWith('/settlements/reverse')) {
        expect(data.keys.toSet(), {
          'allocationId',
          'expectedRevision',
          'reason',
          'amount',
        });
        final row = allocations.firstWhere(
          (r) => r['allocationId'] == data['allocationId'],
        );
        if (row['revision'] != data['expectedRevision']) {
          return jsonResponse({
            'error': {'code': 'REVISION_CONFLICT'},
          }, 409);
        }
        final value = data['amount'] as int;
        if (value > (row['amount'] as int) - (row['reversedAmount'] as int)) {
          return jsonResponse({
            'error': {'code': 'SETTLEMENT_EXCEEDED'},
          }, 409);
        }
        row['reversedAmount'] = (row['reversedAmount'] as int) + value;
        row['revision'] = (row['revision'] as int) + 1;
        row['reason'] = data['reason'];
        sourceRows.single['usedAmount'] =
            (sourceRows.single['usedAmount'] as int) - value;
        settled -= value;
        result = {'businessId': 12345678, 'allocation': row, 'invoice': raw()};
      } else {
        expect(path.endsWith('/v2/payments/reverse'), true);
        expect(data.keys.toSet(), {
          'paymentId',
          'expectedRevision',
          'reason',
          'fundsConfirmed',
        });
        expect(data['fundsConfirmed'], true);
        final payment = paymentRows.firstWhere(
          (r) => r['paymentId'] == data['paymentId'],
        );
        if (payment['revision'] != data['expectedRevision']) {
          return jsonResponse({
            'error': {'code': 'REVISION_CONFLICT'},
          }, 409);
        }
        if (payment['status'] != 'CONFIRMED') {
          return jsonResponse({
            'error': {'code': 'INVALID_STATE'},
          }, 409);
        }
        for (final row in allocations) {
          settled -= (row['amount'] as int) - (row['reversedAmount'] as int);
          row['reversedAmount'] = row['amount'];
          row['revision'] = (row['revision'] as int) + 1;
          row['reason'] = data['reason'];
        }
        sourceRows.single['status'] = 'REVERSED';
        sourceRows.single['usedAmount'] = 0;
        final reversal = <String, dynamic>{
          ...payment,
          'paymentId': reversalId,
          'direction': direction == 'IN' ? 'OUT' : 'IN',
          'purpose': 'REVERSAL',
          'originalPaymentId': payment['paymentId'],
          'note': data['reason'],
          'revision': 1,
        };
        payment['status'] = 'REVERSED';
        payment['revision'] = (payment['revision'] as int) + 1;
        payment['reversedByPaymentId'] = reversalId;
        paymentRows.add(reversal);
        result = {
          'businessId': 12345678,
          'payment': payment,
          'reversal': reversal,
        };
      }
      final saved = jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
      receipts[key] = saved;
      if (lose) {
        lose = false;
        throw TimeoutException('lost correction reply');
      }
      if (wrongReversal && result.containsKey('reversal')) {
        return jsonResponse({
          ...result,
          'reversal': {
            ...(result['reversal'] as Map),
            'routing': {'fundId': original.bankId},
          },
        });
      }
      return jsonResponse(result);
    }
    final reply = await super.respond(request);
    if (request.method == 'POST' &&
        path.endsWith('/settlements') &&
        reply.statusCode == 200) {
      final json = jsonDecode(reply.body) as Map<String, dynamic>;
      final row = {
        ...json['allocation'] as Map<String, dynamic>,
        'revision': 1,
        'reason': 'MANUAL',
      };
      if (!allocations.any((r) => r['allocationId'] == row['allocationId'])) {
        allocations.add(row);
      }
      return jsonResponse({...json, 'allocation': row});
    }
    return reply;
  }

  Future<InvoicePaymentFX> seeded() async {
    final context = await prepare();
    final fx = InvoicePaymentFX(context, summary);
    await fx.send(command(100));
    await fx.send(
      InvoicePaymentCommand('ALLOCATE', {
        'sourceId': original.sourceId,
        'invoiceId': invoiceOne,
        'amount': 100,
      }),
    );
    return fx;
  }
}

InvoicePaymentCommand reverseAllocation(
  InvoiceSettlementAllocation row,
  int value,
) => InvoicePaymentCommand('REVERSE_ALLOCATION', {
  'allocationId': row.id,
  'expectedRevision': row.revision,
  'amount': value,
  'reason': 'اصلاح تخصیص اشتباه',
}, before: row.json);
InvoicePaymentCommand reversePayment(InvoicePaymentDetail row) =>
    InvoicePaymentCommand('REVERSE_PAYMENT', {
      'paymentId': row.payment.id,
      'expectedRevision': row.revision,
      'reason': 'اصلاح پرداخت اشتباه',
      'fundsConfirmed': true,
    }, before: row.json);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var dir = Directory.current;
    while (!File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      if (dir.path == dir.parent.path) throw StateError('Workspace not found');
      dir = dir.parent;
    }
    await (FontLoader('ravi')..addFont(
          File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  });
  tearDown(() {
    toastification.dismissAll(delayForAnimation: false);
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app partial allocation and full payment reversal replay exact durable commands',
      () async {
        final server = CorrectionServer(
          app,
          type: app == 'mik' ? 'SALE' : 'PURCHASE',
        );
        final fx = await server.seeded();
        expect((await fx.sources(availableOnly: false)).single.available, 0);
        final allocation = (await fx.allocations()).single;
        server.lose = true;
        await expectLater(
          fx.send(reverseAllocation(allocation, 40)),
          throwsA(isA<TimeoutException>()),
        );
        var resumed = InvoicePaymentFX(fx.context, server.summary);
        var pending = await resumed.restore();
        expect(pending!.before!['reversedAmount'], 0);
        await resumed.send(pending);
        expect(server.settled, 60);
        expect((await resumed.allocations()).single.activeAmount, 60);
        final row = await resumed.paymentDetail(original.paymentId);
        server.lose = true;
        await expectLater(
          resumed.send(reversePayment(row)),
          throwsA(isA<TimeoutException>()),
        );
        resumed = InvoicePaymentFX(fx.context, server.summary);
        pending = await resumed.restore();
        await resumed.send(pending!);
        expect(server.paymentRows, hasLength(2));
        expect(server.settled, 0);
        expect(
          (await resumed.paymentDetail(original.paymentId)).payment.status,
          'REVERSED',
        );
        expect((await resumed.allocations()).single.activeAmount, 0);
        expect((await resumed.invoiceDetails()).detail.summary.openAmount, 100);
        final reverseWrites = server.writes
            .where((r) => r.url.path.endsWith('/reverse'))
            .toList();
        expect(reverseWrites, hasLength(4));
        for (final pair in [
          [reverseWrites[0], reverseWrites[1]],
          [reverseWrites[2], reverseWrites[3]],
        ]) {
          expect(pair.first.body, pair.last.body);
          expect(
            pair.first.headers['idempotency-key'],
            pair.last.headers['idempotency-key'],
          );
        }
      },
    );
    test(
      '$app reversal permission, credit guard, stale revision and invalid confirmation',
      () async {
        final server = CorrectionServer(app);
        final fx = await server.seeded();
        final row = await fx.paymentDetail(original.paymentId);
        final allocation = (await fx.allocations()).single;
        server.reverseAllowed = false;
        final count = server.writes.length;
        await expectLater(
          fx.send(reversePayment(row)),
          throwsA(isA<AuthError>()),
        );
        expect(server.writes.length, count);
        server.reverseAllowed = true;
        server.credit = false;
        await expectLater(
          fx.send(reverseAllocation(allocation, 20)),
          throwsA(
            isA<AuthError>().having(
              (e) => e.code,
              'code',
              'CREDIT_SALES_DISABLED',
            ),
          ),
        );
        expect(fx.pending, isNull);
        expect(server.settled, 100);
        server.credit = true;
        server.allocations.single['revision'] = 2;
        await expectLater(
          fx.send(reverseAllocation(allocation, 20)),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'REVISION_CONFLICT'),
          ),
        );
        expect(fx.pending, isNull);
        server.foreign = true;
        await expectLater(
          fx.paymentDetail(original.paymentId),
          throwsFormatException,
        );
        await expectLater(fx.allocations(), throwsFormatException);
        server.foreign = false;
        server.wrongReversal = true;
        await expectLater(fx.send(reversePayment(row)), throwsFormatException);
        expect(fx.pending, isNotNull);
        server.wrongReversal = false;
        await fx.send(fx.pending!);
        expect(fx.pending, isNull);
        expect(server.paymentRows, hasLength(2));
      },
    );
    testWidgets(
      '$app native correction forms require reason and actual reversal confirmation',
      (tester) async {
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = CorrectionServer(
          app,
          type: app == 'mik' ? 'SALE' : 'PURCHASE',
        );
        await server.seeded();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: InvoicePaymentScreen(appId: app, invoice: server.summary),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('لغو تخصیص'));
        await tester.tap(find.text('لغو تخصیص'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ثبت لغو تخصیص'));
        await tester.tap(find.text('ثبت لغو تخصیص'));
        await tester.pumpAndSettle();
        expect(
          find.text('دلیل اصلاح را بین ۱ تا ۵۰۰ حرف وارد کنید.'),
          findsOneWidget,
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('correction-reason')),
            matching: find.byType(TextFormField),
          ),
          'اصلاح تخصیص',
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('reverse-allocation-amount')),
            matching: find.byType(TextFormField),
          ),
          '۴۰',
        );
        await tester.ensureVisible(find.text('ثبت لغو تخصیص'));
        await tester.tap(find.text('ثبت لغو تخصیص'));
        await tester.pumpAndSettle();
        expect(server.settled, 60);
        expect(find.text('لغو تخصیص با موفقیت ثبت شد.'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(InvoicePaymentCorrectionScreen), findsNothing);
        await tester.scrollUntilVisible(
          find.text('جزئیات پرداخت'),
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('جزئیات پرداخت'));
        await tester.tap(find.text('جزئیات پرداخت'));
        await tester.pumpAndSettle();
        expect(find.text('مبلغ فعال: 60 تومان'), findsOneWidget);
        final reason = find.descendant(
          of: find.byKey(const ValueKey('correction-reason')),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(reason);
        await tester.enterText(reason, 'اصلاح پرداخت');
        await tester.ensureVisible(find.text('ثبت برگشت پرداخت'));
        await tester.tap(find.text('ثبت برگشت پرداخت'));
        await tester.pumpAndSettle();
        expect(
          find.text('ابتدا بازگشت واقعی وجه را تایید کنید.'),
          findsOneWidget,
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.ensureVisible(find.text('بله'));
        await tester.tap(find.text('بله'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ثبت برگشت پرداخت'));
        await tester.tap(find.text('ثبت برگشت پرداخت'));
        await tester.pumpAndSettle();
        expect(server.settled, 0);
        expect(find.text('برگشت پرداخت با موفقیت ثبت شد.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
