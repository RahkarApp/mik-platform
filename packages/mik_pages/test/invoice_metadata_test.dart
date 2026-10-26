import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_pages/invoice/add/metadata_editor.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets(
    'native invoice metadata keeps the selected minute, trims notes and clears optional due date',
    (tester) async {
      DateTime? due;
      var note = '';
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => editInvoiceMetadata(
                    context,
                    dueAt: due,
                    note: note,
                    onSave: (date, text) {
                      due = date;
                      note = text;
                    },
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
      final date = tester.widget<DateInput>(find.byType(DateInput));
      expect(date.timePicker, isTrue);
      date.controller.text = '۱۴۰۵/۸/۲۹ ۱۶:۰۵';
      tester
              .widget<Input>(find.byKey(const ValueKey('invoice-note')))
              .controller
              .text =
          '  یادداشت نمونه  ';
      await tester.tap(find.text('اعمال اطلاعات'));
      await tester.pumpAndSettle();
      expect(due!.isUtc, isTrue);
      expect(due!.toLocal().hour, 16);
      expect(due!.toLocal().minute, 5);
      expect(due!.second, 0);
      expect(note, 'یادداشت نمونه');
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بدون سررسید'));
      await tester.tap(find.text('اعمال اطلاعات'));
      await tester.pumpAndSettle();
      expect(due, isNull);
      expect(note, 'یادداشت نمونه');
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      Get.reset();
    },
  );
}
