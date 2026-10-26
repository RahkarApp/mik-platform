import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_pages/invoice/read_screen.dart';
import 'package:mik_pages/invoice/screen.dart';
import 'package:mik_pages/reports/reports.dart';
import 'package:mik_router/mik_router.dart';
import 'package:mik_variables/permissions.dart';

void main() {
  tearDown(() {
    PermissionAccess.clear();
    Get.reset();
  });

  testWidgets('the shared invoice entry retains each app context', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) {
            for (final appId in ['mik', 'mikyar']) {
              final page = InvoiceScreen(
                appId: appId,
              ).build(context) as RemoteInvoicesScreen;
              expect(page.appId, appId);
              expect(page.includeProforma, isTrue);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shared report content retains host navigation and embedded layout',
    (tester) async {
      PermissionAccess.useOwner();
      final router = MikRouter(
        appRoutes: {
          '/staff-profit': (_) => const Scaffold(body: Text('staff profit')),
          '/staff-quantity': (_) =>
              const Scaffold(body: Text('staff quantity')),
        },
      );
      await tester.pumpWidget(
        GetMaterialApp(
          onGenerateRoute: router.generateRoute,
          home: const Scaffold(
            body: ReportsTabDashboard(
              appId: 'mikyar',
              profitRoute: '/staff-profit',
              quantityRoute: '/staff-quantity',
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
      await tester.tap(find.text('سود و زیان'));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, '/staff-profit');
      Get.back();
      await tester.pumpAndSettle();
      await tester.tap(find.text('گردش تعدادی کالا'));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, '/staff-quantity');
      expect(tester.takeException(), isNull);
    },
  );
}
