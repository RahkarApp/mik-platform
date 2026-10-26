import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:toastification/toastification.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_components/elements/product_variant_options.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/detail/screen.dart';
import 'package:mik_pages/product/price/screen.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart'
    as persian;

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_price_fixtures.dart';

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
  Finder field(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  );
  for (final app in ['mik', 'mikyar']) {
    testWidgets(
      '$app detail opens price management with native components and creates a zero price',
      (tester) async {
        final server = PriceServer(app);
        server.controller();
        await tester.pumpWidget(
          GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            builder: (context, child) => ToastificationWrapper(child: child!),
            theme: ThemeData(fontFamily: 'ravi'),
            home: ProductDetailScreen(
              appId: app,
              businessId: 12345678,
              productId: productId,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('قیمت‌'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductPricesScreen), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is BTN && w.name == 'افزودن قیمت جدید',
          ),
          findsOneWidget,
        );
        expect(find.text('قیمت‌گذاری محصول'), findsOneWidget);
        await tester.tap(find.text('افزودن قیمت جدید'));
        await tester.pumpAndSettle();
        expect(find.byType(PriceInput), findsOneWidget);
        expect(
          tester
              .widget<ProductPriceForm>(find.byType(ProductPriceForm))
              .embedded,
          true,
        );
        await tester.tap(find.text('اعتبار قیمت'));
        await tester.pumpAndSettle();
        expect(find.byType(DateInput), findsNWidgets(2));
        await tester.enterText(field('price-name'), 'قیمت عمده');
        await tester.enterText(field('price-amount'), '0');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ثبت قیمت'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ثبت قیمت'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductPriceForm), findsNothing);
        expect(find.text('قیمت عمده'), findsOneWidget);
        expect(jsonDecode(server.mutations.single.body)['amount'], 0);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('$app amount edit preserves default and version', (
      tester,
    ) async {
      final server = PriceServer(app)
        ..permissions.remove('pim.price.default.update');
      final c = server.controller();
      await c.load();
      await tester.pumpWidget(
        GetMaterialApp(
          onGenerateRoute: navigation.MikRouter(
            sharedRoutes: SharedRoutes.namedPages,
          ).generateRoute,
          builder: (context, child) => ToastificationWrapper(child: child!),
          theme: ThemeData(fontFamily: 'ravi'),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProductPriceForm(controller: c, item: c.prices.single),
                ),
              ),
              child: const Text('باز کردن'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();
      await tester.enterText(field('price-amount'), '80');
      await tester.ensureVisible(find.text('ویرایش قیمت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ویرایش قیمت'));
      await tester.pumpAndSettle();
      expect(jsonDecode(server.mutations.single.body), {
        'amount': 80,
        'expectedRevision': 3,
      });
      expect(find.byType(ProductPriceForm), findsNothing);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
    testWidgets('$app override dropdowns submit actual title and variant IDs', (
      tester,
    ) async {
      final server = PriceServer(app);
      final c = server.controller();
      await c.load();
      await tester.pumpWidget(
        GetMaterialApp(
          onGenerateRoute: navigation.MikRouter(
            sharedRoutes: SharedRoutes.namedPages,
          ).generateRoute,
          builder: (context, child) => ToastificationWrapper(child: child!),
          theme: ThemeData(fontFamily: 'ravi'),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ProductPriceForm(controller: c, isOverride: true),
                ),
              ),
              child: const Text('باز کردن'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();
      final title = tester.widget<Dropdown>(find.byType(Dropdown).first);
      title.onChange(title.items_Value!.first);
      await tester.pumpAndSettle();
      final variant = tester.widget<Dropdown>(find.byType(Dropdown).last);
      variant.onChange(variant.items_Value!.first);
      await tester.pumpAndSettle();
      await tester.enterText(field('price-amount'), '125');
      await tester.tap(find.text('ثبت قیمت'));
      await tester.pumpAndSettle();
      expect(jsonDecode(server.mutations.single.body), {
        'productPriceId': priceId,
        'variantId': variantId,
        'amount': 125,
      });
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      '$app price screen keeps the old tabs and edits a variant price through its native sheet',
      (tester) async {
        final server = PriceServer(app)..withVariants = true;
        final c = server.controller();
        await tester.pumpWidget(
          GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            builder: (context, child) => ToastificationWrapper(child: child!),
            theme: ThemeData(fontFamily: 'ravi'),
            home: ProductPricesScreen(fx: c.fx, productId: productId),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MyTabBar), findsOneWidget);
        expect(find.text('قیمت‌گذاری اصلی'), findsOneWidget);
        await tester.tap(find.text('بر اساس ویژگی'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductVariantOptions), findsOneWidget);
        expect(find.text('قرمز'), findsOneWidget);
        await tester.tap(find.text('قرمز'));
        await tester.pumpAndSettle();
        expect(find.text('تعیین نشده'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('variant-price-$variantId-$priceId')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ProductPriceForm>(find.byType(ProductPriceForm))
              .embedded,
          true,
        );
        expect(find.byType(Dropdown), findsNothing);
        await tester.enterText(field('price-amount'), '125');
        await tester.ensureVisible(find.text('ثبت قیمت'));
        await tester.tap(find.text('ثبت قیمت'));
        await tester.pumpAndSettle();
        expect(jsonDecode(server.mutations.single.body), {
          'productPriceId': priceId,
          'variantId': variantId,
          'amount': 125,
        });
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
    testWidgets('$app price readers cannot see mutation controls', (
      tester,
    ) async {
      final server = PriceServer(app)
        ..permissions.removeWhere(
          (p) =>
              p != 'pim.price.read' &&
              p != 'pim.product.read' &&
              p != 'pim.variant.read',
        );
      final c = server.controller();
      await tester.pumpWidget(
        GetMaterialApp(
          onGenerateRoute: navigation.MikRouter(
            sharedRoutes: SharedRoutes.namedPages,
          ).generateRoute,
          builder: (context, child) => ToastificationWrapper(child: child!),
          theme: ThemeData(fontFamily: 'ravi'),
          home: ProductPricesScreen(fx: c.fx, productId: productId),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('افزودن قیمت جدید'), findsNothing);
      expect(find.text('ویرایش فروش'), findsNothing);
      expect(find.text('100 تومان'), findsOneWidget);
      expect(server.mutations, isEmpty);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final cancel in [true, false]) {
    testWidgets(
      'DateInput preserves complete initial date/time and cancellation: $cancel',
      (tester) async {
        final ctl = TextEditingController(text: '1405/07/20 13:45');
        String? changed;
        final input = DateInput(
          controller: ctl,
          name: 'تاریخ',
          timePicker: true,
          onChanged: (value) => changed = value as String,
        );
        await tester.pumpWidget(
          GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            builder: (context, child) => ToastificationWrapper(child: child!),
            theme: ThemeData(fontFamily: 'ravi'),
            home: Scaffold(body: input),
          ),
        );
        final result = input.picker(
          tester.element(find.byType(DateInput)),
          ctl,
          true,
          persian.Jalali(1400),
          persian.Jalali(1410),
          (value) => changed = value as String,
        );
        await tester.pumpAndSettle();
        final dialog = tester.widget<persian.DatePickerDialog>(
          find.byType(persian.DatePickerDialog),
        );
        expect(dialog.initialDate, persian.Jalali(1405, 7, 20));
        Navigator.of(tester.element(find.byType(persian.DatePickerDialog)))
            .pop(persian.Jalali(1405, 7, 21));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TimePickerDialog>(find.byType(TimePickerDialog))
              .initialTime,
          const TimeOfDay(hour: 13, minute: 45),
        );
        Navigator.of(tester.element(find.byType(TimePickerDialog)))
            .pop(cancel ? null : const TimeOfDay(hour: 14, minute: 30));
        await tester.pumpAndSettle();
        await result;
        expect(ctl.text, cancel ? '1405/07/20 13:45' : '1405/7/21 14:30');
        expect(changed, cancel ? isNull : '1405/7/21 14:30');
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        ctl.dispose();
      },
    );
  }
}
