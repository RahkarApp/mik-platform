import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_pages/invoice/add/components/item/components/amount.dart';
import 'package:toastification/toastification.dart';
import 'package:mik_pages/invoice/add/components/selectproduct.dart';
import 'package:mik_data/source/remote/models/models.dart';

import '../../mik_data/test/support/pim_fixtures.dart';

void main() {
  tearDown(Get.reset);
  testWidgets(
    'invoice variant row displays actual attribute values with the old color chip style',
    (tester) async {
      final variant = PimVariant.fromJson({
        ...fixturePim(PimResource.variants),
        'optionValues': [
          {'attributeId': attributeId, 'valueId': optionId},
        ],
      });
      final attribute = PimAttribute.fromJson(
        fixturePim(PimResource.attributes),
      );
      var taps = 0;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ProductItemSelect.variant(
              variant: variant,
              attributes: [attribute],
              isSelected: true,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      expect(find.text('رنگ'), findsOneWidget);
      expect(find.text('قرمز'), findsOneWidget);
      expect(find.text('SHIRT-1'), findsNothing);
      final chip = tester
          .widgetList<Container>(find.byType(Container))
          .where(
            (c) =>
                c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).color ==
                    const Color(0xFFFF0000),
          );
      expect(chip, hasLength(1));
      await tester.tap(find.text('قرمز'));
      expect(taps, 1);
      expect(find.byIcon(IconsaxPlusLinear.tick_square), findsOneWidget);
    },
  );
  testWidgets('invoice quantity control preserves exact fractional steps', (
    tester,
  ) async {
    String? changed;
    var removed = false;
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: AmountChangeInvoice.remote(
            quantity: '100.000001',
            locked: false,
            onChanged: (value) => changed = value,
            onRemove: () => removed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(IconsaxPlusBold.add_square));
    expect(changed, '101.000001');
    await tester.tap(find.byIcon(IconsaxPlusBold.minus_square));
    expect(changed, '99.000001');
    expect(removed, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('invoice quantity control rejects overflow instead of rounding', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(
      ToastificationWrapper(
        child: GetMaterialApp(
          home: Scaffold(
            body: AmountChangeInvoice.remote(
              quantity: '9007199254.740991',
              locked: false,
              onChanged: (value) => changed = value,
              onRemove: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(IconsaxPlusBold.add_square));
    await tester.pumpAndSettle();
    expect(changed, isNull);
    expect(find.textContaining('تعداد معتبر نیست'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
