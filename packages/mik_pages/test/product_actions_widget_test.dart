import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_pages/product/detail/screen.dart';
import 'package:mik_pages/product/detail/shop_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'stock_operations_test.dart' as stock;

const shop = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

class ProductActionsServer extends stock.StockServer {
  ProductActionsServer(super.app);
  bool wrongPublication = false;
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final result = await super.respond(request);
      final body = jsonDecode(result.body) as Map<String, dynamic>;
      if (request.url.queryParameters['scopeType'] == 'BUSINESS') {
        (body['permissionCodes'] as List).addAll([
          'pim.product.read',
          'pim.variant.read',
          'shop.store.read',
          'shop.publication.read',
        ]);
      }
      return jsonResponse(body);
    }
    if (path.endsWith('/products/$productId')) {
      requests.add(request);
      return jsonResponse({
        'businessId': 12345678,
        'item': fixturePim(PimResource.products),
      });
    }
    if (path.endsWith('/variants')) {
      requests.add(request);
      return jsonResponse(fixturePimPage(PimResource.variants));
    }
    if (path.endsWith('/variants/$variantId')) {
      requests.add(request);
      return jsonResponse({
        'businessId': 12345678,
        'item': fixturePim(PimResource.variants),
      });
    }
    if (path.endsWith('/inventory/stock')) {
      final response = await super.respond(request);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      (body['items'] as List).add({
        ...balance,
        'balanceId': '99999999-9999-4999-8999-999999999999',
        'variantId': categoryId,
        'productId': categoryId,
      });
      return jsonResponse(body);
    }
    if (path.endsWith('/shops')) {
      requests.add(request);
      return jsonResponse({
        'items': [
          {
            'shopId': shop,
            'businessId': 12345678,
            'branchId': branch,
            'name': 'فروشگاه نمونه',
            'subdomain': 'sample',
            'hosts': ['sample.example.test'],
            'status': 'ACTIVE',
            'syncStatus': 'READY',
            'enabled': true,
            'revision': 1,
            'domainStatus': 'NONE',
            'customDomain': null,
          },
        ],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/shops/$shop/products/$productId/publication')) {
      requests.add(request);
      return jsonResponse({
        'item': {
          'productId': wrongPublication ? categoryId : productId,
          'excluded': false,
          'productPriceId': null,
          'revision': 0,
        },
      });
    }
    return super.respond(request);
  }
}

void main() {
  setUp(resetOnboardingStorage);
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    toastification.dismissAll(delayForAnimation: false);
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    testWidgets(
      '$app product toolbar opens kardex transfer and shop for the same product',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = ProductActionsServer(app);
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              home: ProductDetailScreen(
                appId: app,
                businessId: 12345678,
                productId: productId,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final action in ['کاردکس', 'انتقال']) {
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(server.warehouses.first['name'] as String),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(
              const ValueKey('stock-99999999-9999-4999-8999-999999999999'),
            ),
            findsNothing,
          );
          await tester.tap(
            find.byKey(const ValueKey('stock-${stock.balanceId}')),
          );
          await tester.pumpAndSettle();
          if (action == 'کاردکس') {
            expect(
              server.requests.where(
                (r) => r.url.path.endsWith('/inventory/kardex'),
              ),
              isNotEmpty,
            );
          } else {
            expect(find.text('انبار مقصد'), findsWidgets);
          }
          Get.back();
          await tester.pumpAndSettle();
          Get.back();
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('شاپ'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductShopScreen), findsOneWidget);
        expect(find.text('فروشگاه نمونه'), findsOneWidget);
        expect(find.text('انتشار کالا: مستثنا نشده'), findsOneWidget);
        expect(server.writes, 0);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('$app shop refuses a publication from another product', (
      tester,
    ) async {
      final server = ProductActionsServer(app)..wrongPublication = true;
      await server.prepare();
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            home: ProductShopScreen(
              business: BusinessContext.forApp(app)!,
              productId: productId,
              productName: 'کالا',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('انتشار کالا: مستثنا نشده'), findsNothing);
      expect(find.text('فروشگاه نمونه'), findsNothing);
      expect(server.writes, 0);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
