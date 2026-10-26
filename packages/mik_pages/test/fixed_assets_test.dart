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
import 'package:mik_data/utils/fx/fixed_assets.dart';
import 'package:mik_pages/assets/screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'invoice_payment_test.dart'
    show PaymentServer, fundId, sourceId, paymentId;

class AssetServer extends PaymentServer {
  AssetServer(super.app);
  bool denied = false,
      wrong = false,
      duplicate = false,
      empty = false,
      fail = false;
  bool wrongMovement = false, badAmount = false;
  final assetRequests = <http.Request>[];
  Map<String, dynamic> asset(String id) => {
    'businessId': 12345678,
    'fixedAssetId': id,
    'branchId': wrong ? sourceId : branch,
    'revision': 1,
    'code': id == fundId ? 'A-1' : 'A-2',
    'name': id == fundId ? 'رایانه' : 'میز',
    'status': 'IN_USE',
    'assetCategoryId': sourceId,
    'categorySnapshot': {'name': 'تجهیزات'},
    'source': 'PURCHASE',
    'depreciationMethod': 'NONE',
    'paymentStatus': 'PARTIALLY_PAID',
    'acquisitionCost': 1000,
    'cost': 1000,
    'bookValue': badAmount ? 1000.5 : 1000,
    'accumulatedDepreciation': 0,
    'residualValue': 0,
    'paidAmount': 100,
    'pendingAmount': 200,
    'liabilityAmount': 900,
    'acquiredOn': '2026-10-01',
    'registeredOn': '2026-10-01',
    'depreciatedThrough': '2026-10-01',
    'financialThrough': '2026-10-01',
  };
  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final row = jsonDecode(response.body) as Map<String, dynamic>;
      // A BUSINESS grant alone must never unlock branch assets.
      if (request.url.queryParameters['scopeType'] == 'BUSINESS' || !denied) {
        (row['permissionCodes'] as List).add('accounting.asset.read');
      }
      return jsonResponse(row);
    }
    if (request.url.path.contains('/accounting/assets')) {
      assetRequests.add(request);
      expect(request.method, 'GET');
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      if (fail) {
        return jsonResponse({
          'error': {'code': 'FORBIDDEN'},
        }, 403);
      }
      final path = request.url.path;
      final second = request.url.queryParameters['after'] != null;
      if (path.endsWith('/movements')) {
        expect(request.url.queryParameters['fixedAssetId'], fundId);
        return jsonResponse({
          'businessId': 12345678,
          'items': empty
              ? []
              : [
                  {
                    'assetMovementId': second ? sourceId : paymentId,
                    'fixedAssetId': fundId,
                    'businessId': 12345678,
                    'branchId': fundId,
                    'toBranchId': wrongMovement ? sourceId : branch,
                    'number': second ? 2 : 1,
                    'kind': 'TRANSFER',
                    'financial': true,
                    'effectiveOn': '2026-10-01',
                    'reason': 'انتقال تجهیزات',
                  },
                ],
          'nextCursor': empty || second ? null : paymentId,
        });
      }
      if (!path.endsWith('/assets')) {
        return jsonResponse({
          'businessId': 12345678,
          'item': asset(path.split('/').last),
        });
      }
      return jsonResponse({
        'businessId': 12345678,
        'items': empty ? [] : [asset(second && !duplicate ? sourceId : fundId)],
        'nextCursor': empty || second ? null : fundId,
      });
    }
    return super.respond(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var root = Directory.current;
    while (!File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      if (root.path == root.parent.path) {
        throw StateError('Workspace not found');
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
      '$app assets pagination, detail and inbound transfer history',
      () async {
        final server = AssetServer(app);
        final fx = FixedAssetsFX(await server.prepare());
        expect((await fx.list()).length, 2);
        final detail = await fx.detail(fundId);
        expect(detail.money('bookValue'), 1000);
        expect(detail.money('pendingAmount'), 200);
        final movements = await fx.movements(fundId);
        expect(movements.length, 2);
        expect(movements.first.number, 2);
        server.empty = true;
        expect(await fx.list(), isEmpty);
        expect(await fx.movements(fundId), isEmpty);
      },
    );
    test(
      '$app rejects wrong branch, repeated rows, money and business-only grants',
      () async {
        final server = AssetServer(app);
        final active = await server.prepare();
        final fx = FixedAssetsFX(active);
        server.wrong = true;
        await expectLater(fx.list(), throwsFormatException);
        server.wrong = false;
        server.duplicate = true;
        await expectLater(fx.list(), throwsFormatException);
        server.duplicate = false;
        server.badAmount = true;
        await expectLater(fx.detail(fundId), throwsFormatException);
        server.badAmount = false;
        server.wrongMovement = true;
        await expectLater(fx.movements(fundId), throwsFormatException);
        server.wrongMovement = false;
        server.denied = true;
        final count = server.assetRequests.length;
        await expectLater(fx.list(), throwsA(isA<AuthError>()));
        expect(server.assetRequests.length, count);
        server.denied = false;
        await active.branches();
        await expectLater(fx.list(), throwsA(isA<AuthError>()));
      },
    );
    testWidgets('$app list opens detail and movements, failed refresh alerts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = AssetServer(app);
      await server.prepare();
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            home: FixedAssetsScreen(appId: app),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('رایانه'), findsOneWidget);
      expect(find.text('میز'), findsOneWidget);
      await tester.tap(find.text('رایانه'));
      await tester.pumpAndSettle();
      expect(find.text('جزئیات دارایی'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('گردش دارایی'),
        450,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('گردش دارایی'));
      await tester.pumpAndSettle();
      expect(find.text('گردش‌های قابل مشاهده در این شعبه'), findsOneWidget);
      expect(find.text('انتقال تجهیزات'), findsWidgets);
      Navigator.of(tester.element(find.text('انتقال تجهیزات').first)).pop();
      await tester.pumpAndSettle();
      server.fail = true;
      await tester.tap(find.text('دریافت مجدد'));
      await tester.pumpAndSettle();
      expect(find.textContaining('مجوز مشاهده'), findsWidgets);
      expect(find.text('گردش دارایی'), findsNothing);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
