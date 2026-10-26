import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_pages/customers/crm/remote_screen.dart';
import 'package:mik_pages/loans/screen.dart';
import 'package:mik_pages/routing/shared_routes.dart';
import 'package:mik_pages/sms/screen.dart';
import 'package:mik_router/mik_router.dart';

void main() {
  tearDown(Get.reset);

  for (final appId in ['mik', 'mikyar']) {
    test(
      '$appId named pages retain the selected app and optional arguments',
      () {
        final routes = SharedRoutes.namedPages;
        final loans = routes[RoutesName.LOANS]!(
          RouteSettings(arguments: {'appId': appId, 'loanId': 'selected-loan'}),
        ) as LoansScreen;
        expect(loans.appId, appId);
        expect(loans.loanId, 'selected-loan');
        final crm = routes[RoutesName.CUSTOMER_CRM]!(
          RouteSettings(
            arguments: {'appId': appId, 'customerId': 'selected-customer'},
          ),
        ) as CustomerCrmScreen;
        expect(crm.appId, appId);
        expect(crm.customerId, 'selected-customer');
        final sms = routes[RoutesName.BUSINESS_SMS]!(
          RouteSettings(arguments: {'appId': appId, 'section': 'history'}),
        ) as BusinessSmsScreen;
        expect(sms.appId, appId);
        expect(sms.section, 'history');
      },
    );
  }

  test('missing or incorrect named page arguments are rejected', () {
    final build = SharedRoutes.namedPages[RoutesName.LOANS]!;
    expect(() => build(const RouteSettings()), throwsArgumentError);
    expect(
      () => build(const RouteSettings(arguments: {'appId': 1})),
      throwsArgumentError,
    );
  });

  testWidgets('named pages return typed results and can reopen the same path', (
    tester,
  ) async {
    final received = <Object?>[];
    final router = MikRouter(
      sharedRoutes: {
        '/selection': (settings) {
          received.add(settings.arguments);
          return const Scaffold(body: Text('selection'));
        },
      },
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: Text('home')),
        onGenerateRoute: router.generateRoute,
      ),
    );
    final firstArgs = {
      'selected': <String>['one'],
    };
    final first = Get.toNamed(
      '/selection',
      arguments: firstArgs,
      preventDuplicates: false,
    );
    await tester.pumpAndSettle();
    final secondArgs = {
      'selected': <String>['two'],
    };
    final second = Get.toNamed(
      '/selection',
      arguments: secondArgs,
      preventDuplicates: false,
    );
    await tester.pumpAndSettle();
    expect(received, [same(firstArgs), same(secondArgs)]);
    expect(Get.arguments, same(secondArgs));
    Get.back(result: ('two', true));
    await tester.pumpAndSettle();
    final (String, bool)? secondResult = await second;
    expect(secondResult, ('two', true));
    expect(find.text('selection'), findsOneWidget);
    Get.back(result: <String>['one']);
    await tester.pumpAndSettle();
    final List<String>? firstResult = await first;
    expect(firstResult, ['one']);
    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Get.back closes MyBottomSheet and retains its parent page', (
    tester,
  ) async {
    BuildContext? pageContext;
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('parent'));
          },
        ),
      ),
    );
    final result = MyBottomSheet.view(
      pageContext!,
      title: 'selection',
      child: (_) => const Text('sheet content'),
    );
    await tester.pumpAndSettle();
    Get.back(result: 'chosen');
    await tester.pumpAndSettle();
    expect(await result, 'chosen');
    expect(find.text('sheet content'), findsNothing);
    expect(find.text('parent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
