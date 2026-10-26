import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_data/source/remote/models/invoice_amounts.dart';
import 'package:mik_pages/invoice/add/amounts_editor.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets(
    'native money editor applies explicit adjustments inside the existing bottom sheet',
    (tester) async {
      InvoiceAmounts? saved;
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => editInvoiceAmounts(
                    context,
                    initial: const InvoiceAmounts(),
                    subtotal: 100,
                    canDiscount: true,
                    canSurcharge: true,
                    onSave: (value) => saved = value,
                  ),
                  child: const Text('باز کردن'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();
      expect(find.byType(PriceInput), findsNWidgets(4));
      final inputs = tester
          .widgetList<PriceInput>(find.byType(PriceInput))
          .toList();
      inputs[0].controller.text = '۱۰ تومان';
      inputs[1].controller.text = '۲۰ تومان';
      await tester.tap(find.text('اعمال مبالغ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(saved!.total(100), 110);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      Get.reset();
    },
  );
  test('invoice adjustments use integer tomans, respect goods discount limit and avoid overflow', () {
    expect(InvoiceAmounts.parse('۱٬۲۳۴ تومان'), 1234);
    expect(InvoiceAmounts.parse(''), 0);
    expect(() => InvoiceAmounts.parse('-1'), throwsFormatException);
    expect(() => InvoiceAmounts.parse('1.5'), throwsFormatException);
    expect(
      const InvoiceAmounts(
        discount: 10,
        shipping: 20,
        surcharge: 3,
        tax: 7,
      ).total(100),
      120,
    );
    expect(const InvoiceAmounts(discount: 100).total(100), 0);
    expect(
      () => const InvoiceAmounts(discount: 101).total(100),
      throwsFormatException,
    );
    expect(
      () => const InvoiceAmounts(tax: 1).total(9007199254740991),
      throwsFormatException,
    );
    expect(const InvoiceAmounts().payload, isEmpty);
    expect(
      const InvoiceAmounts(
        tax: 7,
        purchaseTaxTreatment: 'NON_RECOVERABLE',
      ).payload,
      {'taxAmount': 7, 'purchaseTaxTreatment': 'NON_RECOVERABLE'},
    );
  });
}
