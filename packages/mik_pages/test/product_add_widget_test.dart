import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/input/unitInput.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/input/barcodeInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/add/screen.dart';
import 'package:mik_pages/product/screen/screen.dart';
import 'package:mik_pages/product/screen/tabs/controllers/product.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_pages/routing/shared_routes.dart';

import '../../mik_data/test/support/pim_fixtures.dart';
import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'support/product_add_fixtures.dart';

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
      '$app single-add menu opens the registered page and refreshes on return',
      (tester) async {
        resetOnboardingStorage();
        final server = AddServer(app);
        server.controller();
        productDashboardController.search.value = '';
        final router = MikRouter(
          sharedRoutes: app == 'mik'
              ? SharedRoutes.pages()
              : {
                  RoutesName.PRODUCTADD: (s) =>
                      PimProductAddScreen.fromArguments(
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
              body: ProductTabDashboard(
                appId: app,
                controller: ProductTabDashboardController(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('محصول جدید'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('افزودن تکی'));
        await tester.pumpAndSettle();
        expect(find.byType(PimProductAddScreen), findsOneWidget);
        Get.back();
        await tester.pumpAndSettle();
        expect(find.byType(PimProductAddScreen), findsNothing);
        expect(find.byType(PimProductItem), findsOneWidget);
        expect(server.mutations, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      '$app submits the existing form sections and returns after verified success',
      (tester) async {
        final server = AddServer(app);
        final c = server.controller();
        await tester.pumpWidget(
          GetMaterialApp(
            theme: ThemeData(fontFamily: 'ravi'),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PimProductAddScreen(
                      context: c.fx.context,
                      controller: c,
                    ),
                  ),
                ),
                child: const Text('باز کردن'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('باز کردن'));
        await tester.pumpAndSettle();
        expect(find.text('افزودن محصول'), findsOneWidget);
        expect(find.text('اطلاعات محصول:'), findsOneWidget);
        expect(find.byType(UnitInput), findsOneWidget);
        expect(find.byType(PriceInput), findsOneWidget);
        expect(find.byType(BarcodeInput), findsOneWidget);
        c.category(categoryId, true);
        c.unitId.value = 1;
        await tester.pumpAndSettle();
        final name = find.descendant(
          of: find.byKey(const ValueKey('product-name')),
          matching: find.byType(TextField),
        );
        await tester.enterText(name, 'پیراهن');
        final price = find.descendant(
          of: find.byKey(const ValueKey('product-price')),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(price);
        await tester.enterText(price, '0');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ثبت محصول'));
        await tester.tap(find.text('ثبت محصول'));
        await tester.pumpAndSettle();
        expect(find.byType(PimProductAddScreen), findsNothing);
        expect(server.mutations, hasLength(3));
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$app a failed price locks fields and offers recovery instead of duplicate creation',
      (tester) async {
        final server = AddServer(app)..failPrice = true;
        final c = await server.ready();
        expect(await c.save(name: 'پیراهن', price: '10'), isFalse);
        await tester.pumpWidget(
          GetMaterialApp(
            theme: ThemeData(fontFamily: 'ravi'),
            home: PimProductAddScreen(context: c.fx.context, controller: c),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('ادامهٔ ثبت قبلی'), findsOneWidget);
        expect(find.byType(Input), findsNothing);
        expect(find.text('محصول‌های در حال ثبت: پیراهن'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      '$app rejects legacy or cross-business add arguments before requests',
      (tester) async {
        final server = AddServer(app);
        server.controller();
        await tester.pumpWidget(
          MaterialApp(
            home: PimProductAddScreen.fromArguments({
              'appId': app,
              'businessId': 87654321,
            }, appId: app),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('کسب‌وکار مسیر محصول معتبر نیست.'), findsOneWidget);
        expect(server.requests, isEmpty);
      },
    );
  }
}
