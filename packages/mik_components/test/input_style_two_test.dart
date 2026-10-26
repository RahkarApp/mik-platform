import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_variables/variable.dart';

void main() {
  tearDown(() {
    darkMode.value = false;
    Get.reset();
  });
  testWidgets(
    'style two label stays above the fill, readable and tappable in both themes',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      for (final setting in [
        (false, null),
        (true, null),
        (true, Colors.white),
        (false, Colors.black),
      ]) {
        darkMode.value = setting.$1;
        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Input(
                key: ValueKey(setting),
                controller: controller,
                name: 'نام فروشگاه',
                style: 2,
                fillColor: setting.$2,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = find.text('نام فروشگاه:');
        expect(label, findsOneWidget);
        final input = find.byType(TextFormField);
        final stack = tester.widget<Stack>(
          find.ancestor(of: input, matching: find.byType(Stack)).first,
        );
        // The label must be painted after the filled field, rather than hidden behind it.
        expect(stack.children.last, isA<IgnorePointer>());
        final field = tester.widget<TextField>(
          find.descendant(of: input, matching: find.byType(TextField)),
        );
        final foreground = tester.widget<Text>(label).style!.color!;
        final fill = field.decoration!.fillColor!;
        final luminances = [
          foreground.computeLuminance(),
          fill.computeLuminance(),
        ]..sort();
        expect(
          (luminances.last + 0.05) / (luminances.first + 0.05),
          greaterThan(4.5),
        );
        await tester.tapAt(tester.getCenter(label));
        await tester.pump();
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.enterText(input, 'فروشگاه من');
        expect(controller.text, 'فروشگاه من');
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
