import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/payment_list.dart';
import 'package:mik_pages/bill/remote_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'invoice_payment_test.dart'
    show PaymentServer, fundId, paymentId, sourceId;
import 'invoice_read_test.dart' show partyId;

class ListServer extends PaymentServer {
  ListServer(super.app);
  bool denied = false,
      duplicate = false,
      wrong = false,
      empty = false,
      fail = false;
  int reads = 0;
  Map<String, dynamic> record(bool second) => {
    'businessId': wrong ? 87654321 : 12345678,
    'paymentId': second ? sourceId : paymentId,
    'partyId': partyId,
    'partyType': 'CUSTOMER',
    'branchId': fundId,
    'method': second ? 'CHEQUE' : 'CASH',
    'direction': second ? 'OUT' : 'IN',
    'status': second ? 'PENDING' : 'CONFIRMED',
    'amount': second ? 200 : 100,
    'createdAt': '2026-10-24T10:00:00.000Z',
    'revision': 1,
    'purpose': second ? 'REFUND' : 'SETTLEMENT',
    'financialVersion': 2,
  };
  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (denied) {
        (data['permissionCodes'] as List).remove('accounting.payment.read');
      }
      return jsonResponse(data);
    }
    if (request.url.path.contains('/v2/payments')) {
      reads++;
      expect(request.method, 'GET');
      expect(request.headers['x-branch-id'], branch);
      if (fail) {
        return jsonResponse({
          'error': {'code': 'FORBIDDEN'},
        }, 403);
      }
      if (!request.url.path.endsWith('/payments')) {
        return jsonResponse({
          'businessId': 12345678,
          'item': record(request.url.path.endsWith(sourceId)),
        });
      }
      final second = request.url.queryParameters['after'] != null;
      expect(
        request.url.queryParameters.keys.toSet(),
        second ? {'limit', 'after'} : {'limit'},
      );
      return jsonResponse({
        'businessId': 12345678,
        'items': empty ? [] : [record(second && !duplicate)],
        'nextCursor': empty || second ? null : paymentId,
      });
    }
    return super.respond(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    for (final family in ['ravi', 'raviLight']) {
      await (FontLoader(family)..addFont(
            File('../../mik-app/assets/fonts/RaviLight.ttf')
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
      '$app all pages, actual direction and other branches remain visible',
      () async {
        final server = ListServer(app);
        final fx = PaymentListFX(await server.prepare());
        final rows = await fx.load();
        expect(
          rows.map((r) => r.payment.direction),
          containsAll(['IN', 'OUT']),
        );
        expect(rows.every((r) => r.payment.branchId == fundId), isTrue);
        expect(rows.last.payment.status, 'PENDING');
        expect(server.reads, 2);
        final detail = await fx.detail(sourceId);
        expect(detail.purpose, 'REFUND');
        server.empty = true;
        expect(await fx.load(), isEmpty);
      },
    );
    test(
      '$app rejects wrong scope, repeated cursor, permission and changed context',
      () async {
        final server = ListServer(app);
        final context = await server.prepare();
        final fx = PaymentListFX(context);
        server.wrong = true;
        await expectLater(fx.load(), throwsFormatException);
        server.wrong = false;
        server.duplicate = true;
        await expectLater(fx.load(), throwsFormatException);
        server.duplicate = false;
        server.denied = true;
        final count = server.reads;
        await expectLater(fx.load(), throwsA(isA<AuthError>()));
        expect(server.reads, count);
        server.denied = false;
        await context.branches();
        await expectLater(fx.load(), throwsA(isA<AuthError>()));
      },
    );
    testWidgets('$app tabs, current detail and failed fetch alert', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = ListServer(app);
      await server.prepare();
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            home: RemoteBillScreen(appId: app),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('100 تومان'), findsOneWidget);
      expect(find.text('200 تومان'), findsNothing);
      await tester.tap(find.text('پرداخت'));
      await tester.pumpAndSettle();
      expect(find.text('200 تومان'), findsOneWidget);
      expect(find.text('در انتظار'), findsOneWidget);
      await tester.tap(find.text('200 تومان'));
      await tester.pumpAndSettle();
      expect(find.text('استرداد وجه'), findsOneWidget);
      Navigator.of(tester.element(find.text('استرداد وجه'))).pop();
      await tester.pumpAndSettle();
      server.fail = true;
      await tester.tap(find.text('دریافت مجدد'));
      await tester.pumpAndSettle();
      expect(find.text('200 تومان'), findsNothing);
      expect(find.textContaining('مجوز مشاهده'), findsWidgets);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
