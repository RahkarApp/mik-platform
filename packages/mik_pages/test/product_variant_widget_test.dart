import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';
import 'package:mik_components/elements/buttons/button.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/variant/screen.dart';
import 'package:mik_pages/product/detail/screen.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_variant_fixtures.dart';

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

  for (final app in ['mik', 'mikyar']) {
    testWidgets('$app previews and generates with project components', (
      tester,
    ) async {
      final server = VariantServer(app);
      final c = server.controller();
      await tester.pumpWidget(
        GetMaterialApp(
          onGenerateRoute: navigation.MikRouter(
            sharedRoutes: SharedRoutes.namedPages,
          ).generateRoute,
          theme: ThemeData(fontFamily: 'ravi'),
          home: ProductVariantsScreen(fx: c.fx, productId: productId),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MiniBTN), findsWidgets);
      expect(find.byType(MyDivider), findsWidgets);
      expect(
        find.byWidgetPredicate(
          (w) => w is BTN && w.name == 'پیش‌نمایش ترکیب‌ها',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('پیش‌نمایش ترکیب‌ها'));
      await tester.pumpAndSettle();
      expect(find.textContaining('موجود، فعال'), findsOneWidget);
      expect(find.textContaining('جدید'), findsWidgets);
      await tester.ensureVisible(find.text('ساخت تنوع‌های جدید'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ساخت تنوع‌های جدید'));
      await tester.pumpAndSettle();
      expect(server.rows, hasLength(2));
      expect(server.mutations, hasLength(1));
      await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 تنوع جدید'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('$app archive requires confirmation and restore is separate', (
      tester,
    ) async {
      final server = VariantServer(app);
      server.product['status'] = 'DRAFT';
      server.permissions.remove('pim.variant.create');
      final c = server.controller();
      await tester.pumpWidget(
        GetMaterialApp(
          onGenerateRoute: navigation.MikRouter(
            sharedRoutes: SharedRoutes.namedPages,
          ).generateRoute,
          theme: ThemeData(fontFamily: 'ravi'),
          home: ProductVariantsScreen(fx: c.fx, productId: productId),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('پیش‌نمایش ترکیب‌ها'), findsNothing);
      await tester.ensureVisible(find.text('آرشیو تنوع'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('آرشیو تنوع'));
      await tester.pumpAndSettle();
      expect(server.mutations, isEmpty);
      await tester.tap(find.text('آرشیو تنوع').last);
      await tester.pumpAndSettle();
      expect(server.rows.single['status'], 'ARCHIVED');
      expect(find.text('فعال‌سازی تنوع'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('$app detail opens shared variant manager', (tester) async {
      final server = VariantServer(app);
      server.controller();
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
      await tester.ensureVisible(find.text('ویژگی‌'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ویژگی‌'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductVariantsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
