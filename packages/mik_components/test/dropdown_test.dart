import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/input/dropdown.dart';

void main() {
  testWidgets(
    'single selection resolves rebuilt defaults and clears unavailable options',
    (tester) async {
      late StateSetter rebuild;
      var options = [
        ItemValue(text: 'قرمز', data: 'red'),
        ItemValue(text: 'آبی', data: 'blue'),
      ];
      ItemValue? selected = const ItemValue(text: '', data: 'red');
      var changes = 0;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Dropdown(
                  name: 'رنگ',
                  itemValue: true,
                  search: false,
                  items_Value: options,
                  defaultValue: selected,
                  onChange: (value) {
                    changes++;
                    setState(
                      () => selected = ItemValue(
                        text: '',
                        data: (value as ItemValue).data,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('قرمز'), findsOneWidget);
      expect(tester.takeException(), isNull);
      rebuild(
        () => options = [
          ItemValue(text: 'قرمز تازه', data: 'red'),
          ItemValue(text: 'آبی', data: 'blue'),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('قرمز تازه'), findsOneWidget);
      expect(changes, 0);
      rebuild(() => options = [ItemValue(text: 'آبی', data: 'blue')]);
      await tester.pumpAndSettle();
      expect(find.text('قرمز تازه'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(Dropdown));
      await tester.pumpAndSettle();
      await tester.tap(find.text('آبی').last);
      await tester.pumpAndSettle();
      expect(selected!.data, 'blue');
      expect(changes, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      Get.reset();
    },
  );

  testWidgets(
    'multi selection notifies only on interaction and survives rebuilds',
    (tester) async {
      final selected = <String>[].obs;
      var changes = 0;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Obx(() {
              final options = [
                const ItemValue(text: 'قرمز', data: 'red'),
                const ItemValue(text: 'آبی', data: 'blue'),
              ];
              return Dropdown(
                name: 'رنگ‌ها',
                itemValue: true,
                multiSelect: true,
                items_Value: options,
                defaultValue: options
                    .where((item) => selected.contains(item.data))
                    .toList(),
                onChange: (value) {
                  changes++;
                  selected.assignAll(
                    List<ItemValue>.from(value)
                        .map((item) => item.data as String),
                  );
                },
              );
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(changes, 0);
      await tester.tap(find.byType(Dropdown));
      await tester.pumpAndSettle();
      await tester.tap(find.text('قرمز').last);
      await tester.pumpAndSettle();
      expect(selected, ['red']);
      expect(changes, 1);
      await tester.tap(find.text('آبی').last);
      await tester.pumpAndSettle();
      expect(selected, ['red', 'blue']);
      expect(changes, 2);
      await tester.tap(find.text('قرمز').last);
      await tester.pumpAndSettle();
      expect(selected, ['blue']);
      expect(changes, 3);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      Get.reset();
    },
  );

  testWidgets(
    'multiple disabled dropdowns keep independent values and controllers',
    (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Dropdown(
                  name: 'اول',
                  disable: true,
                  defaultValue: 'فعال',
                  items_String: ['فعال'],
                  onChange: (_) {},
                ),
                Dropdown(
                  name: 'دوم',
                  disable: true,
                  defaultValue: 'عدد',
                  items_String: ['عدد'],
                  onChange: (_) {},
                ),
                Dropdown(
                  name: 'سوم',
                  disable: true,
                  itemValue: true,
                  defaultValue: const ItemValue(text: 'قرمز', data: 'red'),
                  items_Value: const [ItemValue(text: 'قرمز', data: 'red')],
                  onChange: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('فعال'), findsOneWidget);
      expect(find.text('عدد'), findsOneWidget);
      expect(find.text('قرمز'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      Get.reset();
    },
  );
}
