import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/source/remote/models/inventory_quantity.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/product_facts.dart';
import 'package:mik_pages/product/screen/screen.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

class ControlledFacts extends ProductFactsFX {
  Future<ProductFacts> Function() response;
  int calls = 0;
  ControlledFacts(String app, this.response)
    : super(pimFixture(MockClient((_) async => jsonResponse({})), appId: app));
  @override
  Future<ProductFacts> load(PimProduct product) {
    calls++;
    return response();
  }
}

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
    Future<void> mount(WidgetTester tester, ControlledFacts facts) =>
        tester.pumpWidget(
          GetMaterialApp(
            theme: ThemeData(fontFamily: 'ravi'),
            home: Scaffold(
              body: SizedBox(
                width: 500,
                child: PimProductItem(
                  PimProduct.fromJson(fixturePim(PimResource.products)),
                  categories: 'پوشاک',
                  facts: facts,
                ),
              ),
            ),
          ),
        );
    testWidgets('$app row loads exact availability and all-title price range', (
      tester,
    ) async {
      final pending = Completer<ProductFacts>();
      final facts = ControlledFacts(app, () => pending.future);
      await mount(tester, facts);
      expect(find.text('قابل فروش: …'), findsOneWidget);
      pending.complete(
        ProductFacts(
          const ProductPriceSummary(minimum: 0, maximum: 120),
          ProductStockSummary(
            available: InventoryQuantity.fromJson('1234.000001'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('قیمت: 0 - 120 تومان'), findsOneWidget);
      expect(find.text('قابل فروش: 1,234.000001'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
      '$app unknown price preserves explicit zero stock and supports retry',
      (tester) async {
        final facts = ControlledFacts(
          app,
          () async => ProductFacts(
            const ProductPriceSummary(message: 'خطای قیمت'),
            ProductStockSummary(
              available: InventoryQuantity.fromJson('0'),
              blockedForCount: true,
            ),
          ),
        );
        await mount(tester, facts);
        await tester.pumpAndSettle();
        expect(find.text('قیمت: —'), findsOneWidget);
        expect(find.text('قابل فروش: 0'), findsOneWidget);
        expect(find.byTooltip('خطای قیمت'), findsOneWidget);
        expect(
          find.byTooltip(
            'قابل فروش: 0؛ انبار پیش‌فرض شعبه؛ انبارگردانی باز است.',
          ),
          findsOneWidget,
        );
        facts.response = () async => const ProductFacts(
          ProductPriceSummary(minimum: 0, maximum: 0),
          ProductStockSummary(message: 'عدم دسترسی'),
        );
        await tester.tap(find.text('قیمت: —'));
        await tester.pumpAndSettle();
        expect(facts.calls, 2);
        expect(find.text('قیمت: 0 تومان'), findsOneWidget);
        expect(find.text('قابل فروش: —'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
