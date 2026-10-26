import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/dashboard_read.dart';
import 'package:mik_data/utils/fx/profit_report.dart';
import 'package:mik_pages/reports/quantity_unavailable.dart';
import 'package:mik_pages/reports/remote_profit.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'dashboard_read_test.dart' show DashboardServer;

class ProfitServer extends DashboardServer {
  ProfitServer(super.app);
  @override
  Map<String, dynamic> profit(http.Request request) => {
    ...super.profit(request),
    'netSales': 500,
    'costOfGoodsSold': 200,
    'otherIncome': 0,
    'expenses': 400,
    'grossProfit': complete ? 300 : null,
    'provisional': {'grossProfit': 300, 'netProfitBeforeIncomeTax': -100},
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    for (final family in ['ravi', 'raviLight']) {
      await (FontLoader(family)..addFont(
            File('../../mik-app/assets/fonts/RaviLight.ttf')
                .readAsBytes()
                .then(ByteData.sublistView),
          ))
          .load();
    }
  });
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app period boundaries, dashboard parity, incomplete profit and snapshot rejection',
      () async {
        final server = ProfitServer(app), clock = DateTime(2026, 10, 21, 12);
        final dashboard = DashboardReadFX(await server.prepare()),
            fx = ProfitReportFX(dashboard);
        var result = await fx.load('هفته', now: clock);
        final home = await dashboard.profitChart(month: false, now: clock);
        expect(
          result.points.map((p) => p.current),
          home.points.map((p) => p.current),
        );
        expect(
          result.points.map((p) => p.previous),
          home.points.map((p) => p.previous),
        );
        expect(result.money('costOfGoodsSold'), 200);
        expect(result.grossProfit, 300);
        expect(result.summary.profit, -100);
        for (final period in ['ماه', 'فصل', 'سال']) {
          result = await fx.load(period, now: clock);
          expect(
            result.points.length,
            period == 'ماه'
                ? inInclusiveRange(29, 31)
                : period == 'فصل'
                ? inInclusiveRange(13, 14)
                : 12,
          );
        }
        expect(
          server.profitRequests.every((r) {
            final start = DateTime.parse(r.url.queryParameters['startAt']!)
                .toLocal();
            return start.hour == 0 && start.minute == 0 && start.second == 0;
          }),
          isTrue,
        );
        server.complete = false;
        result = await fx.load('هفته', now: clock);
        expect(result.incomplete, isTrue);
        expect(result.summary.profit, isNull);
        expect(result.grossProfit, isNull);
        expect(
          result.points.every((p) => p.current == null && p.previous == null),
          isTrue,
        );
        server.complete = true;
        server.mixed = true;
        server.profitCalls = 0;
        await expectLater(
          fx.load('هفته', now: clock),
          throwsA(
            isA<AuthError>().having(
              (e) => e.code,
              'code',
              'REPORT_SNAPSHOT_CHANGED',
            ),
          ),
        );
        server.mixed = false;
        server.fail = true;
        await expectLater(
          fx.load('هفته', now: clock),
          throwsA(isA<AuthError>()),
        );
      },
    );
    testWidgets(
      '$app existing profit controls, fullscreen, breakdown and failed refresh',
      (tester) async {
        tester.view.physicalSize = app == 'mik'
            ? const Size(1200, 800)
            : const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = ProfitServer(app);
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              home: RemoteProfitReport(appId: app),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('نمودار سود هفتگی '), findsOneWidget);
        var chart = tester.widget<SfCartesianChart>(
          find.byType(SfCartesianChart),
        );
        expect(chart.series.first, isA<LineSeries>());
        await tester.tap(find.text('نمودار میله‌ای'));
        await tester.pumpAndSettle();
        chart = tester.widget<SfCartesianChart>(find.byType(SfCartesianChart));
        expect(chart.series.first, isA<ColumnSeries>());
        final calls = server.profitCalls;
        await tester.tap(find.text('تمام صفحه'));
        await tester.pumpAndSettle();
        expect(find.text('بازگشت'), findsWidgets);
        expect(server.profitCalls, calls);
        await tester.tap(find.text('جزئیات گزارش'));
        await tester.pumpAndSettle();
        expect(find.text('بهای تمام‌شده کالای فروش‌رفته'), findsOneWidget);
        expect(find.text('200 تومان'), findsOneWidget);
        expect(find.text('-100 تومان'), findsOneWidget);
        Navigator.of(tester.element(find.text('بهای تمام‌شده کالای فروش‌رفته')))
            .pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('سال'));
        await tester.pumpAndSettle();
        expect(find.text('نمودار سود سالانه '), findsOneWidget);
        server.fail = true;
        await tester.tap(find.text('دریافت مجدد'));
        await tester.pumpAndSettle();
        expect(find.byType(SfCartesianChart), findsNothing);
        expect(find.textContaining('مجوز مشاهده'), findsWidgets);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
    testWidgets(
      '$app unsupported quantity report never reads a local product cache',
      (tester) async {
        final server = ProfitServer(app);
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              home: QuantityReportUnavailable(appId: app),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(quantityReportLimitation), findsWidgets);
        expect(find.text('مشاهده انبارها و کاردکس موجود'), findsOneWidget);
        expect(server.profitRequests, isEmpty);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
