import 'package:mik_router/mik_router.dart' as navigation;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/input/unitInput.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/detail/screen.dart';
import 'package:mik_pages/product/edit/screen.dart';
import 'package:mik_pages/product/screen/screen.dart';
import 'package:mik_pages/product/screen/tabs/controllers/product.dart';
import 'package:mik_pages/routing/shared_routes.dart';
import 'package:mik_router/routing.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_edit_fixtures.dart';

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
  setUp(resetOnboardingStorage);
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  Finder input(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  );
  for (final app in ['mik', 'mikyar']) {
    testWidgets('$app read-only grants hide both edit actions', (tester) async {
      final server = EditServer(app)
        ..permissions.removeWhere((p) => p.endsWith('.update'));
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
      await tester.pumpAndSettle();
      expect(find.text('ویرایش'), findsNothing);
      expect(find.text('ویرایش تنوع'), findsNothing);
      expect(server.patches, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
      '$app edited name refreshes details and its parent product list',
      (tester) async {
        final server = EditServer(app)..activate();
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
              body: ProductTabDashboard(
                appId: app,
                controller: ProductTabDashboardController(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('پیراهن'));
        await tester.pumpAndSettle();
        expect(find.byType(MiniBTN), findsWidgets);
        expect(find.text('بر اساس ویژگی'), findsOneWidget);
        await tester.tap(find.text('ویرایش'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductEditScreen), findsOneWidget);
        expect(find.byType(UnitInput), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<int>), findsNothing);
        await tester.enterText(input('edit-name'), 'نام تازه');
        await tester.ensureVisible(find.text('ذخیره تغییرات'));
        await tester.tap(find.text('ذخیره تغییرات'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductEditScreen), findsNothing);
        expect(find.text('نام تازه'), findsOneWidget);
        Get.back();
        await tester.pumpAndSettle();
        expect(find.byType(ProductDetailScreen), findsNothing);
        expect(find.text('نام تازه'), findsOneWidget);
        expect(server.patches, hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('$app variant form edits SKU and newline-separated barcodes', (
      tester,
    ) async {
      final server = EditServer(app)..activate();
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
      await tester.tap(
        find.byKey(const PageStorageKey('product-variant-$variantId')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ویرایش تنوع'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ویرایش تنوع'));
      await tester.pumpAndSettle();
      await tester.enterText(input('edit-sku'), 'SKU-2');
      await tester.enterText(input('edit-barcodes'), '111\n222\n');
      await tester.ensureVisible(find.text('ذخیره تغییرات'));
      await tester.tap(find.text('ذخیره تغییرات'));
      await tester.pumpAndSettle();
      expect(server.variant['sku'], 'SKU-2');
      expect(server.variant['barcodes'], ['111', '222']);
      expect(find.byType(ProductEditScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
      '$app conflict preserves entered text until explicit replacement with latest data',
      (tester) async {
        final server = EditServer(app);
        final fx = server.activate();
        await tester.pumpWidget(
          GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: ProductEditScreen(fx: fx, productId: productId),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(input('edit-name'), 'ویرایش من');
        server.product['name'] = 'ویرایش همکار';
        server.product['revision'] = 10;
        await tester.ensureVisible(find.text('ذخیره تغییرات'));
        await tester.tap(find.text('ذخیره تغییرات'));
        await tester.pumpAndSettle();
        expect(find.text('دریافت نسخه جدید و جایگزینی فرم'), findsOneWidget);
        expect(
          tester.widget<TextField>(input('edit-name')).controller?.text,
          'ویرایش من',
        );
        expect(server.patches, hasLength(1));
        await tester.tap(find.text('دریافت نسخه جدید و جایگزینی فرم'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(input('edit-name')).controller?.text,
          'ویرایش همکار',
        );
        expect(server.patches, hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
