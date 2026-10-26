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
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/fixed_asset.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_data/utils/fx/asset_payments.dart';
import 'package:mik_pages/assets/payment_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'fixed_assets_test.dart' show AssetServer;
import 'invoice_payment_test.dart'
    show fundId, bankId, paymentId, sourceId, allocationId;

class AssetPaymentServer extends AssetServer {
  AssetPaymentServer(super.app) {
    current = {
      ...super.asset(fundId),
      'supplierId': fundId,
      'paidAmount': 0,
      'pendingAmount': 0,
      'liabilityAmount': 1000,
      'paymentStatus': 'UNPAID',
    };
  }
  late Map<String, dynamic> current;
  final assetPaymentRows = <Map<String, dynamic>>[];
  final paymentWrites = <http.Request>[];
  final paymentReceipts = <String, Map<String, dynamic>>{};
  bool losePaymentReply = false,
      allowPay = true,
      wrongResult = false,
      wrongPage = false;
  @override
  Map<String, dynamic> asset(String id) => {...current, 'fixedAssetId': id};
  void refresh() {
    final paid = assetPaymentRows
        .where((r) => r['status'] == 'CONFIRMED')
        .fold<int>(0, (sum, r) => sum + (r['amount'] as int));
    final pending = assetPaymentRows
        .where((r) => r['status'] == 'PENDING')
        .fold<int>(0, (sum, r) => sum + (r['amount'] as int));
    current = {
      ...current,
      'revision': (current['revision'] as int) + 1,
      'paidAmount': paid,
      'pendingAmount': pending,
      'liabilityAmount': 1000 - paid,
      'paymentStatus': paid == 1000
          ? 'PAID'
          : paid == 0
          ? 'UNPAID'
          : 'PARTIALLY_PAID',
    };
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final row = jsonDecode(response.body) as Map<String, dynamic>;
      if (request.url.queryParameters['scopeType'] == 'BRANCH') {
        (row['permissionCodes'] as List).addAll([
          if (allowPay) 'accounting.asset.payment.pay',
          'accounting.asset.payment.reverse',
          'accounting.cheque.clear',
          'accounting.expense.cheque.pay',
          'accounting.treasury.use',
        ]);
      }
      return jsonResponse(row);
    }
    if (path.endsWith('/treasury/options')) {
      expect(request.url.queryParameters['kind'], 'fund');
      return jsonResponse({
        'businessId': 12345678,
        'items': [
          {
            'fundId': fundId,
            'name': 'صندوق شعبه',
            'kind': 'CASH',
            'branchId': branch,
          },
          {'fundId': bankId, 'name': 'حساب بانکی', 'kind': 'BANK'},
        ],
        'nextCursor': null,
      });
    }
    if (path.contains('/assets/payments') ||
        path.endsWith('/assets/cheques/status')) {
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      if (request.method == 'GET') {
        expect(request.url.queryParameters['fixedAssetId'], fundId);
        final after = request.url.queryParameters['after'];
        final rows = assetPaymentRows
            .where(
              (p) =>
                  after == null ||
                  (p['assetPaymentId'] as String).compareTo(after) > 0,
            )
            .toList();
        return jsonResponse({
          'businessId': 12345678,
          'items': rows
              .take(1)
              .map((r) => {...r, if (wrongPage) 'fixedAssetId': bankId})
              .toList(),
          'nextCursor': rows.length > 1 ? rows.first['assetPaymentId'] : null,
        });
      }
      paymentWrites.add(request);
      final body = jsonDecode(request.body) as Map<String, dynamic>,
          key = request.headers['idempotency-key']!;
      if (!paymentReceipts.containsKey(key)) {
        late Map<String, dynamic> result;
        if (body.containsKey('payment')) {
          expect(body['fixedAssetId'], fundId);
          expect(body['expectedRevision'], current['revision']);
          final input = body['payment'] as Map<String, dynamic>;
          result = {
            'businessId': 12345678,
            'assetPaymentId': [
              paymentId,
              sourceId,
              allocationId,
            ][assetPaymentRows.length],
            'fixedAssetId': fundId,
            'supplierId': fundId,
            'branchId': branch,
            'revision': 1,
            'amount': input['amount'],
            'method': input['method'],
            'routing': input['routing'],
            if (input['cheque'] != null) 'cheque': input['cheque'],
            'status': input['method'] == 'CHEQUE' ? 'PENDING' : 'CONFIRMED',
          };
          assetPaymentRows.add(result);
        } else {
          final i = assetPaymentRows.indexWhere(
            (p) => p['assetPaymentId'] == body['assetPaymentId'],
          );
          expect(body['expectedRevision'], assetPaymentRows[i]['revision']);
          result = {
            ...assetPaymentRows[i],
            'revision': (assetPaymentRows[i]['revision'] as int) + 1,
            'status': path.endsWith('/reverse') ? 'REVERSED' : body['status'],
          };
          assetPaymentRows[i] = result;
        }
        refresh();
        paymentReceipts[key] = {
          'businessId': 12345678,
          'asset': {...current},
          'payment': {...result},
        };
      }
      if (losePaymentReply) {
        losePaymentReply = false;
        throw TimeoutException('Lost payment reply');
      }
      final response = paymentReceipts[key]!;
      return jsonResponse(
        wrongResult ? {...response, 'businessId': 87654321} : response,
      );
    }
    return super.respond(request);
  }
}

AssetPaymentCommand pay(
  RemoteFixedAsset row,
  int amount, {
  bool cheque = false,
  bool bank = false,
}) => AssetPaymentCommand(
  'payment',
  {
    'fixedAssetId': row.id,
    'expectedRevision': row.revision,
    'payment': {
      'amount': amount,
      'method': cheque
          ? 'CHEQUE'
          : bank
          ? 'BANK_TRANSFER'
          : 'CASH',
      'confirmed': true,
      'routing': {'fundId': cheque || bank ? bankId : fundId},
      if (cheque)
        'cheque': {
          'bankName': 'بانک نمونه',
          'number': '1234',
          'sayadId': '1234567890123456',
          'dueAt': '2026-11-01T00:00:00.000Z',
        },
    },
  },
  before: {'asset': row.json},
);
AssetPaymentCommand resolve(
  RemoteFixedAsset row,
  AssetPayment payment,
  String status,
) => AssetPaymentCommand(
  status == 'REVERSED' ? 'reverse' : 'cheque',
  {
    'assetPaymentId': payment.id,
    'expectedRevision': payment.revision,
    'reason': 'نتیجه واقعی',
    if (status == 'REVERSED')
      'fundsConfirmed': true
    else ...{
      'confirmed': true,
      'status': status,
    },
  },
  before: {'asset': row.json, 'payment': payment.json},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var root = Directory.current;
    while (!File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      if (root.path == root.parent.path) {
        throw StateError('Workspace missing');
      }
      root = root.parent;
    }
    for (final family in ['ravi', 'raviLight']) {
      await (FontLoader(family)..addFont(
            File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
                .readAsBytes()
                .then(ByteData.sublistView),
          ))
          .load();
    }
  });
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app cash, pending cheque, settlement and reversal preserve liability',
      () async {
        final server = AssetPaymentServer(app);
        final fx = AssetPaymentsFX(
          FixedAssetsFX(await server.prepare()),
          fundId,
        );
        var row = await fx.assets.detail(fundId);
        expect((await fx.targets('CASH')).single.id, fundId);
        expect((await fx.targets('CHEQUE')).single.id, bankId);
        await fx.send(pay(row, 200));
        row = await fx.assets.detail(fundId);
        await fx.send(pay(row, 300, cheque: true));
        row = await fx.assets.detail(fundId);
        expect(row.money('paidAmount'), 200);
        expect(row.money('pendingAmount'), 300);
        expect(row.money('liabilityAmount'), 800);
        expect(row.uncoveredAmount, 500);
        var payments = await fx.payments(row);
        expect(payments.length, 2);
        await fx.send(resolve(row, payments.last, 'CONFIRMED'));
        row = await fx.assets.detail(fundId);
        expect(row.money('paidAmount'), 500);
        expect(row.money('pendingAmount'), 0);
        payments = await fx.payments(row);
        await fx.send(resolve(row, payments.first, 'REVERSED'));
        row = await fx.assets.detail(fundId);
        expect(row.money('paidAmount'), 300);
        expect(row.money('liabilityAmount'), 700);
        await fx.send(pay(row, 100, cheque: true));
        row = await fx.assets.detail(fundId);
        payments = await fx.payments(row);
        await fx.send(resolve(row, payments.last, 'RETURNED'));
        expect((await fx.assets.detail(fundId)).uncoveredAmount, 700);
      },
    );
    test(
      '$app exact recovery, invalid scope and denied payment never duplicate writes',
      () async {
        final server = AssetPaymentServer(app);
        final assets = FixedAssetsFX(await server.prepare());
        final fx = AssetPaymentsFX(assets, fundId),
            row = await assets.detail(fundId);
        server.allowPay = false;
        await expectLater(
          fx.send(pay(row, 100, bank: true)),
          throwsA(isA<AuthError>()),
        );
        expect(server.paymentWrites, isEmpty);
        server.allowPay = true;
        server.losePaymentReply = true;
        await expectLater(
          fx.send(pay(row, 100, bank: true)),
          throwsA(isA<TimeoutException>()),
        );
        final recovered = AssetPaymentsFX(assets, fundId),
            pending = await fx.restore();
        await recovered.send(pending!);
        expect(server.assetPaymentRows.length, 1);
        expect(server.paymentWrites[0].body, server.paymentWrites[1].body);
        expect(
          server.paymentWrites[0].headers['idempotency-key'],
          server.paymentWrites[1].headers['idempotency-key'],
        );
        server.wrongPage = true;
        await expectLater(
          recovered.payments(await assets.detail(fundId)),
          throwsFormatException,
        );
        server.wrongPage = false;
        server.wrongResult = true;
        await expectLater(
          recovered.send(pay(await assets.detail(fundId), 50)),
          throwsFormatException,
        );
        expect(await recovered.restore(), isNotNull);
      },
    );
    testWidgets(
      '$app native payment form registers cash and displays real totals',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = AssetPaymentServer(app);
        final assets = FixedAssetsFX(await server.prepare()),
            row = RemoteFixedAsset(server.current);
        final fx = AssetPaymentsFX(assets, fundId);
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              home: AssetPaymentScreen(fx: fx, asset: row),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('asset-payment-amount')),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        final input = tester.widget<Input>(
          find.byKey(const ValueKey('asset-payment-amount')),
        );
        input.controller.text = '100';
        await tester.tap(find.text('صندوق شعبه'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('ثبت پرداخت دارایی'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('ثبت پرداخت دارایی'));
        await tester.pumpAndSettle();
        expect(server.assetPaymentRows.single['amount'], 100);
        await tester.scrollUntilVisible(
          find.text('پرداخت‌شده: 100 تومان'),
          -350,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('مانده بدون پوشش: 900 تومان'), findsOneWidget);
        server.fail = true;
        await tester.scrollUntilVisible(
          find.text('دریافت مجدد پرداخت‌ها'),
          -350,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('دریافت مجدد پرداخت‌ها'));
        await tester.pumpAndSettle();
        expect(find.textContaining('مجوز مشاهده'), findsWidgets);
        expect(find.text('مانده بدون پوشش: 900 تومان'), findsNothing);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
