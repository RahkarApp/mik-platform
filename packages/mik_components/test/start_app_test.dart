import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/startup/start_app.dart';
import 'package:mik_variables/variable.dart';

void main() {
  tearDown(() {
    Get.reset();
    darkMode.value = false;
  });

  testWidgets('the shared shell starts once and keeps route arguments', (
    tester,
  ) async {
    var starts = 0;
    final rebuild = ValueNotifier<int>(0);
    await tester.pumpWidget(
      ValueListenableBuilder<int>(
        valueListenable: rebuild,
        builder: (_, value, child) => StartApp(
          title: 'میک',
          home: const Scaffold(body: Text('startup')),
          useSystemTheme: () => false,
          onStart: () async => starts++,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text('${settings.arguments}')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    rebuild.value++;
    await tester.pumpAndSettle();
    expect(starts, 1);
    final context = tester.element(find.text('startup'));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(MediaQuery.textScalerOf(context).scale(16), 16);
    expect(Theme.of(context).textTheme.bodyMedium?.fontFamily, 'ravi');
    Get.toNamed('/details?tab=1', arguments: 'record-id');
    await tester.pumpAndSettle();
    expect(find.text('record-id'), findsOneWidget);
    expect(starts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    rebuild.dispose();
  });

  testWidgets(
    'system brightness respects the saved preference and stops after disposal',
    (tester) async {
      final dispatcher = tester.binding.platformDispatcher;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      var useSystem = true;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(
        StartApp(
          title: 'میکیار',
          home: const Scaffold(body: Text('startup')),
          onGenerateRoute: (_) => null,
          useSystemTheme: () => useSystem,
        ),
      );
      await tester.pumpAndSettle();
      dispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(darkMode.value, isTrue);
      expect(
        Theme.of(tester.element(find.text('startup'))).brightness,
        Brightness.dark,
      );
      useSystem = false;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(darkMode.value, isTrue);
      useSystem = true;
      await tester.pumpWidget(const SizedBox.shrink());
      dispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pump();
      expect(darkMode.value, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
