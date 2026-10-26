import 'package:toastification/toastification.dart';
import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/variant/screen.dart';
import 'package:mik_pages/product/variant/axes_screen.dart';
import 'package:mik_pages/product/variant/option_screen.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_axes_fixtures.dart';
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
    testWidgets(
      '$app edits existing options from manager and refreshes product without generation',
      (tester) async {
        final s = AxesServer(app);
        final c = s.controller();
        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => ToastificationWrapper(child: child!),
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: ProductVariantsScreen(fx: c.fx, productId: productId),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('ویرایش گزینه‌های محصول'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductAxesScreen), findsOneWidget);
        expect(find.byType(MyDivider), findsWidgets);
        final red = find.byKey(
          const ValueKey('axis-option-$attributeId-$optionId'),
        );
        expect(tester.widget<CheckboxListTile>(red).onChanged, isNull);
        await tester.tap(
          find.byKey(
            const ValueKey('axis-option-$attributeId-$secondOptionId'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ذخیره گزینه‌های محصول'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ذخیره گزینه‌های محصول'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductAxesScreen), findsNothing);
        expect(s.mutations, hasLength(1));
        expect(s.rows, hasLength(1));
        expect(find.text('آبی'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      '$app creates color with native input and picker then explicitly saves product',
      (tester) async {
        final s = AxesServer(app);
        final c = s.axesController();
        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => ToastificationWrapper(child: child!),
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: ProductAxesScreen(fx: c.fx, productId: productId),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('افزودن گزینهٔ جدید به رنگ'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductOptionScreen), findsOneWidget);
        expect(find.byType(Input), findsOneWidget);
        expect(find.byType(MiniBTN), findsWidgets);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('variant-option-name')),
            matching: find.byType(TextField),
          ),
          'مشکی',
        );
        await tester.tap(find.text('انتخاب رنگ'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('تأیید رنگ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('تأیید رنگ'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ثبت گزینهٔ جدید'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ثبت گزینهٔ جدید'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductOptionScreen), findsNothing);
        expect(find.text('مشکی'), findsOneWidget);
        expect(s.mutations, hasLength(1));
        final values = jsonDecode(s.mutations.single.body)['values'] as List;
        expect(values.last['colorHex'], '#000000');
        await tester.ensureVisible(find.text('ذخیره گزینه‌های محصول'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ذخیره گزینه‌های محصول'));
        await tester.pumpAndSettle();
        expect(s.mutations, hasLength(2));
        expect(s.rows, hasLength(1));
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('$app uncertain global option resumes through the manager', (
      tester,
    ) async {
      final server = AxesServer(app)..unavailable = true;
      final initial = server.axesController();
      await initial.load();
      expect(
        await initial.addOption(
          attribute: initial.attributes.first,
          name: 'سبز',
          colorHex: '#00FF00',
        ),
        isFalse,
      );
      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => ToastificationWrapper(child: child!),
          onGenerateRoute: navigation.MikRouter(
            sharedRoutes: SharedRoutes.namedPages,
          ).generateRoute,
          theme: ThemeData(fontFamily: 'ravi'),
          home: ProductVariantsScreen(fx: initial.fx, productId: productId),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ادامهٔ مدیریت گزینه‌ها'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('تلاش مجدد همان درخواست گزینهٔ جدید'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تلاش مجدد همان درخواست گزینهٔ جدید'));
      await tester.pumpAndSettle();
      expect(server.mutations, hasLength(2));
      expect(server.mutations.first.body, server.mutations.last.body);
      expect(
        server.mutations.first.headers['idempotency-key'],
        server.mutations.last.headers['idempotency-key'],
      );
      expect(find.text('ذخیره گزینه‌های محصول'), findsOneWidget);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('$app option editing is hidden without assign permission', (
      tester,
    ) async {
      final s = AxesServer(app)..permissions.remove('pim.attribute.assign');
      final c = s.controller();
      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => ToastificationWrapper(child: child!),
          onGenerateRoute: navigation.MikRouter(
            sharedRoutes: SharedRoutes.namedPages,
          ).generateRoute,
          theme: ThemeData(fontFamily: 'ravi'),
          home: ProductVariantsScreen(fx: c.fx, productId: productId),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ویرایش گزینه‌های محصول'), findsNothing);
      expect(s.mutations, isEmpty);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
      '$app attribute conflict is visible and requires explicit reload',
      (tester) async {
        final s = AxesServer(app)..conflict = true;
        final c = s.axesController();
        await c.load();
        // Explicit reload discards the unsaved product selection after a conflict.
        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => ToastificationWrapper(child: child!),
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: ProductAxesScreen(fx: c.fx, productId: productId),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('آبی'));
        await tester.ensureVisible(find.text('ذخیره گزینه‌های محصول'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ذخیره گزینه‌های محصول'));
        await tester.pumpAndSettle();
        expect(
          find.text('دریافت نسخه جدید و جایگزینی انتخاب‌ها'),
          findsOneWidget,
        );
        expect(s.mutations, hasLength(1));
        s.conflict = false;
        await tester.tap(find.text('دریافت نسخه جدید و جایگزینی انتخاب‌ها'));
        await tester.pumpAndSettle();
        expect(find.text('ذخیره گزینه‌های محصول'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
