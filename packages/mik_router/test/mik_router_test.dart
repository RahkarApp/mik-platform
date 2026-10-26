import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mik_router/mik_router.dart';

void main() {
  testWidgets('app page overrides a shared page with the same path', (
    tester,
  ) async {
    final router = MikRouter(
      sharedRoutes: {'/': (_) => const Text('shared')},
      appRoutes: {'/': (_) => const Text('private')},
    );
    await tester.pumpWidget(MaterialApp(onGenerateRoute: router.generateRoute));
    expect(find.text('private'), findsOneWidget);
    expect(find.text('shared'), findsNothing);
  });

  testWidgets('a shared page receives query and original arguments', (
    tester,
  ) async {
    RouteSettings? received;
    final args = {'id': 7};
    final router = MikRouter(
      sharedRoutes: {
        '/': (s) {
          received = s;
          return const Text('shared');
        },
      },
    );
    final route = router.generateRoute(
      RouteSettings(name: '/?filter=active', arguments: args),
    );
    expect(route.settings.arguments, same(args));
    expect(received?.name, '/?filter=active');
    await tester.pumpWidget(
      MaterialApp(home: Navigator(onGenerateRoute: (_) => route)),
    );
    expect(find.text('shared'), findsOneWidget);
  });

  testWidgets('guard redirects before a protected page is constructed', (
    tester,
  ) async {
    var protectedBuilt = false;
    final router = MikRouter(
      sharedRoutes: {
        '/': (_) {
          protectedBuilt = true;
          return const Text('private');
        },
        '/login': (_) => const Text('login'),
      },
      guard: (_) => const RouteSettings(name: '/login'),
    );
    await tester.pumpWidget(MaterialApp(onGenerateRoute: router.generateRoute));
    expect(protectedBuilt, isFalse);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('unknown pages show a fallback instead of opening a dashboard', (
    tester,
  ) async {
    final router = MikRouter();
    await tester.pumpWidget(MaterialApp(onGenerateRoute: router.generateRoute));
    expect(find.text('صفحهٔ موردنظر پیدا نشد.'), findsOneWidget);
  });

  testWidgets('invalid arguments show a controlled error page', (tester) async {
    final router = MikRouter(
      sharedRoutes: {
        '/': (s) {
          RouteArguments(s).required<int>('id');
          return const Text('detail');
        },
      },
    );
    await tester.pumpWidget(MaterialApp(onGenerateRoute: router.generateRoute));
    expect(
      find.text('اطلاعات لازم برای نمایش این صفحه موجود نیست.'),
      findsOneWidget,
    );
  });

  test('normalizes query strings and custom deep links', () {
    final router = MikRouter(
      sharedRoutes: {'/product/pro': (_) => const SizedBox()},
    );
    expect(router.canHandle('rahkarapp://mik/product/pro?id=1'), isTrue);
    expect(router.canHandle('/unknown'), isFalse);
    expect(MikRouter.pathOf(null), '/');
  });

  test(
    'route arguments reject a wrong model type and support optional values',
    () {
      final args = RouteArguments(const RouteSettings(arguments: {'id': '7'}));
      expect(() => args.required<int>('id'), throwsArgumentError);
      expect(args.optional<String>('missing'), isNull);
    },
  );
}
