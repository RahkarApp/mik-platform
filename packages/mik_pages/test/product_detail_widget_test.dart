import 'package:mik_router/mik_router.dart' as navigation;
import 'package:toastification/toastification.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/detail/screen.dart';
import 'package:mik_pages/product/screen/screen.dart';
import 'package:mik_pages/product/screen/tabs/controllers/product.dart';
import 'package:mik_pages/routing/shared_routes.dart';
import 'package:mik_router/routing.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_detail_fixtures.dart';
import '../../mik_data/test/product_facts_test.dart' as facts;

void main() {
  setUpAll(() async {
    var root = Directory.current;
    while (!File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
            .existsSync() &&
        root.parent.path != root.path) {
      root = root.parent;
    }
    await (FontLoader('ravi')..addFont(
          File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        ))
        .load();
  });
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    testWidgets(
      '$app opens fresh read-only details from the row and returns to its list',
      (tester) async {
        final server = DetailServer(app)..activate();
        final c = ProductTabDashboardController();
        productDashboardController.search.value = '';
        final router = MikRouter(
          sharedRoutes: app == 'mik'
              ? SharedRoutes.pages()
              : {
                  ...SharedRoutes.namedPages,
                  RoutesName.PRODUCTDETAILS: (s) =>
                      ProductDetailScreen.fromArguments(
                        s.arguments,
                        appId: app,
                      ),
                },
        );
        await tester.pumpWidget(
          GetMaterialApp(
            theme: ThemeData(fontFamily: 'ravi'),
            onGenerateRoute: router.generateRoute,
            home: Scaffold(
              body: ProductTabDashboard(appId: app, controller: c),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('پیراهن'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductDetailScreen), findsOneWidget);
        expect(find.text('جزئیات محصول'), findsOneWidget);
        expect(find.text('بر اساس ویژگی'), findsOneWidget);
        await tester.tap(find.text('بر اساس انبار'));
        await tester.pumpAndSettle();
        expect(find.text('ابتدا شعبه را انتخاب کنید.'), findsWidgets);
        await tester.tap(find.text('مشخصات'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('توضیح واقعی سرور', findRichText: true),
          findsOneWidget,
        );
        expect(find.textContaining('M-10', findRichText: true), findsOneWidget);
        expect(find.text('ویرایش'), findsNothing);
        expect(find.text('انتقال موجودی'), findsNothing);
        expect(server.requests.map((r) => r.method), everyElement('GET'));
        Get.back();
        await tester.pumpAndSettle();
        Get.back();
        await tester.pumpAndSettle();
        expect(find.byType(ProductDetailScreen), findsNothing);
        expect(find.byType(PimProductItem), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('$app details show loading, not-found and successful retry', (
      tester,
    ) async {
      final server = DetailServer(app)
        ..pendingProduct = Completer<http.Response>();
      server.activate();
      await tester.pumpWidget(
        GetMaterialApp(
          onGenerateRoute: navigation.MikRouter(
            sharedRoutes: SharedRoutes.namedPages,
          ).generateRoute,
          theme: ThemeData(fontFamily: 'ravi'),
          home: ProductDetailScreen(
            appId: app,
            businessId: 12345678,
            productId: productId,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      server.pendingProduct!.complete(
        jsonResponse({
          'error': {'code': 'RECORD_NOT_FOUND'},
        }, 404),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('وجود ندارد'), findsNWidgets(2));
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();
      expect(find.textContaining('وجود ندارد'), findsOneWidget);
      expect(find.byType(PimProductItem), findsNothing);
      server.pendingProduct = null;
      await tester.tap(find.text('تلاش مجدد'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('product-detail-summary')),
        findsOneWidget,
      );
      expect(find.text('بر اساس ویژگی'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
      '$app product style tabs preserve real price and default warehouse stock',
      (tester) async {
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final records = DetailServer(app);
        final values = facts.FactsServer(app)
          ..variants = [variantId]
          ..permissions.add('pim.product.read');
        final fx = pimFixture(
          MockClient((request) {
            if (request.url.path.contains('/products')) {
              return records.respond(request);
            }
            if (request.url.path.endsWith('/variants') &&
                request.url.queryParameters['status'] == null) {
              return records.respond(request);
            }
            return values.respond(request);
          }),
          appId: app,
        );
        await fx.authorize();
        await fx.context.selectBranch((await fx.context.branches()).single);
        await tester.pumpWidget(
          GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: ProductDetailScreen(
              appId: app,
              businessId: 12345678,
              productId: productId,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('0.1'), findsWidgets);
        expect(find.text('0 - 100 تومان'), findsWidgets);
        await tester.tap(
          find.byKey(const PageStorageKey('product-variant-$variantId')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('1234567890', findRichText: true),
          findsOneWidget,
        );
        final requests = values.requests.length;
        await tester.tap(find.text('بر اساس انبار'));
        await tester.pumpAndSettle();
        expect(find.text('انبار پیش‌فرض شعبه'), findsOneWidget);
        expect(find.text('0.1'), findsWidgets);
        await tester.tap(find.text('بر اساس ویژگی'));
        await tester.pumpAndSettle();
        expect(values.requests, hasLength(requests));
        expect(
          values.requests.where((r) => r.url.path.endsWith('/availability')),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('$app legacy and cross-app arguments fail without HTTP', (
      tester,
    ) async {
      final server = DetailServer(app)..activate();
      for (final args in [
        {'item': productId},
        {
          'appId': app == 'mik' ? 'mikyar' : 'mik',
          'businessId': 12345678,
          'productId': productId,
        },
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: ProductDetailScreen.fromArguments(args, appId: app),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('اطلاعات مسیر محصول معتبر نیست.'), findsOneWidget);
      }
      expect(server.requests, isEmpty);
    });
  }
}
