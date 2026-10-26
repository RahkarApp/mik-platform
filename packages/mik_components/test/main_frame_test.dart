import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mik_components/base/main/main.dart';

void main() {
  testWidgets('a late response cannot replace another page controller', (
    tester,
  ) async {
    final first = Completer<Object>();
    await tester.pumpWidget(
      MaterialApp(
        home: Main(
          key: const ValueKey('first-page'),
          initState: () => first.future,
          child: (data) => Text('$data'),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Main(
          key: const ValueKey('second-page'),
          initState: () async => 'second result',
          child: (data) => Text('$data'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    first.complete('late first result');
    await tester.pumpAndSettle();
    expect(find.text('second result'), findsOneWidget);
    expect(find.text('late first result'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('page initialization runs once across parent rebuilds', (
    tester,
  ) async {
    var loads = 0;
    final rebuild = ValueNotifier<int>(0);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (_, value, child) => Main(
            initState: () async {
              loads++;
              return 'loaded';
            },
            child: (data) => Text('$data / $value'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.text('loaded / 0'), findsOneWidget);
    rebuild.value = 1;
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.text('loaded / 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    rebuild.dispose();
  });

  testWidgets('page content fills the available width', (tester) async {
    const contentKey = ValueKey('page-content');
    await tester.pumpWidget(
      MaterialApp(
        home: Main(
          initState: () async => '',
          child: (_) => const SizedBox(key: contentKey),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(contentKey)).width,
      tester.getSize(find.byType(Scaffold)).width,
    );
  });

  testWidgets('finishing an async load after disposal does not update state', (
    tester,
  ) async {
    var release = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Main(
          initState: () async {
            await Future<void>.delayed(const Duration(seconds: 1));
            release = true;
            return 'loaded';
          },
          child: (data) => Text('$data'),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(release, isTrue);
    expect(tester.takeException(), isNull);
  });
}
