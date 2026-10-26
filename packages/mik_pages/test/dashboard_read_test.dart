import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/dashboard_read.dart';
import 'package:mik_pages/dashboard/invoices.dart';
import 'package:mik_pages/dashboard/profit_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'financial_reports_test.dart' as previous;
import 'invoice_read_test.dart' show invoiceOne, invoiceTwo;

class DashboardServer extends previous.ReportServer {
  DashboardServer(super.app);
  bool complete = true, mixed = false, fail = false, wrong = false;
  int profitCalls = 0;
  final profitRequests = <http.Request>[];
  Map<String, dynamic> profit(http.Request request) => {
    'businessId': 12345678,
    'scope': 'BRANCH',
    'branchIds': [wrong ? previous.recordId : branch],
    'snapshot': {
      'sequence': mixed && profitCalls > 1 ? 6 : 5,
      'asOf': '2026-10-24T10:00:00.000Z',
    },
    'currency': 'TOMAN',
    'basis': 'PHYSICAL_DISPATCH_AND_POSTED_EXPENSES',
    'startAt': request.url.queryParameters['startAt'],
    'endAt': request.url.queryParameters['endAt'],
    'complete': complete,
    'netProfitBeforeIncomeTax': complete ? -100 : null,
    'coverage': {
      'inventorySequence': 7,
      'unknownCosts': complete ? 0 : 1,
      'missingCostPostings': 0,
      'pending': 0,
      'failed': 0,
      'inventoryChanged': false,
    },
  };
  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/authorization')) {
      final original = await super.respond(request),
          row = jsonDecode(original.body) as Map<String, dynamic>;
      if (allowReports) {
        (row['permissionCodes'] as List).add('accounting.report.profit');
      }
      return jsonResponse(row);
    }
    if (request.url.path.endsWith('/reports/profit')) {
      profitCalls++;
      profitRequests.add(request);
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      expect(request.url.queryParameters['scope'], 'BRANCH');
      if (fail) {
        return jsonResponse({
          'error': {'code': 'FORBIDDEN'},
        }, 403);
      }
      return jsonResponse(profit(request));
    }
    if (request.url.path.endsWith('/v2/invoices')) {
      final type = request.url.queryParameters['types']!;
      final first = base.summary(type),
          second = {
            ...base.summary(type),
            'invoiceId': invoiceTwo,
            'rootInvoiceId': invoiceTwo,
            'number': '000002',
          };
      first['createdAt'] = DateTime.now()
          .subtract(const Duration(days: 1))
          .toUtc()
          .toIso8601String();
      second['createdAt'] = DateTime.now()
          .subtract(const Duration(days: 2))
          .toUtc()
          .toIso8601String();
      return jsonResponse({
        'businessId': 12345678,
        'items': type != 'SALE'
            ? []
            : request.url.queryParameters['after'] == null
            ? [first]
            : [second],
        'nextCursor':
            type == 'SALE' && request.url.queryParameters['after'] == null
            ? invoiceOne
            : null,
      });
    }
    return super.respond(request);
  }
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
      '$app dashboard dates, coverage, versions, authorization and invoice pagination',
      () async {
        final server = DashboardServer(app), clock = DateTime(2026, 10, 21, 12);
        final fx = DashboardReadFX(await server.prepare());
        var result = await fx.profitChart(month: false, now: clock);
        expect(result.points.length, 7);
        expect(result.incomplete, isFalse);
        expect(
          result.points
              .where((p) => p.current != null)
              .every((p) => p.current == -100),
          isTrue,
        );
        expect(result.points.any((p) => p.current == null), isTrue);
        expect(
          server.profitRequests.every(
            (r) =>
                !DateTime.parse(r.url.queryParameters['endAt']!)
                    .isAfter(clock.toUtc()),
          ),
          isTrue,
        );
        server.complete = false;
        result = await fx.profitChart(month: true, now: clock);
        expect(result.points.length, inInclusiveRange(29, 31));
        expect(result.incomplete, isTrue);
        expect(
          result.points.every((p) => p.current == null && p.previous == null),
          isTrue,
        );
        server.complete = true;
        server.mixed = true;
        server.profitCalls = 0;
        await expectLater(
          fx.profitChart(month: false, now: clock),
          throwsA(
            isA<AuthError>().having(
              (e) => e.code,
              'code',
              'REPORT_SNAPSHOT_CHANGED',
            ),
          ),
        );
        server.mixed = false;
        server.wrong = true;
        await expectLater(
          fx.profitChart(month: false, now: clock),
          throwsFormatException,
        );
        server.wrong = false;
        await fx.profit(
          DateTime.utc(2026, 10, 1, 0, 0, 0, 123, 456),
          DateTime.utc(2026, 10, 2, 0, 0, 0, 789, 123),
        );
        expect(
          server.profitRequests.last.url.queryParameters['startAt'],
          '2026-10-01T00:00:00.123Z',
        );
        expect(
          server.profitRequests.last.url.queryParameters['endAt'],
          '2026-10-02T00:00:00.789Z',
        );
        final invoices = await fx.invoices();
        expect(invoices.map((r) => r.id), [invoiceTwo, invoiceOne]);
        final summary = await fx.financial();
        expect(summary.receivable, 0);
        expect(summary.payable, 200);
        expect(summary.cash, 900);
        server.allowReports = false;
        await expectLater(
          fx.profitChart(month: false, now: clock),
          throwsA(isA<AuthError>()),
        );
        fx.context.clearAccess();
        await expectLater(fx.invoices(), throwsA(isA<AuthError>()));
      },
    );
    testWidgets(
      '$app profit chart preserves bounds and uses gaps for incomplete profit',
      (tester) async {
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = DashboardServer(app)..complete = false;
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              home: Scaffold(
                body: RemoteProfitHomeChart(appId: app, height: 200),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final chart = tester.widget<SfCartesianChart>(
          find.byType(SfCartesianChart),
        );
        expect(tester.getSize(find.byType(SfCartesianChart)).height, 200);
        expect(chart.series.length, 2);
        expect(find.textContaining('بخشی از سود'), findsOneWidget);
        expect(find.text('سود این هفته'), findsOneWidget);
        server.fail = true;
        await tester.tap(find.byIcon(IconsaxPlusLinear.setting_5));
        await tester.pumpAndSettle();
        await tester.tap(find.text('دریافت مجدد'));
        await tester.pumpAndSettle();
        expect(find.byType(SfCartesianChart), findsNothing);
        expect(find.textContaining('مجوز مشاهده'), findsWidgets);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'Mik invoice summary preserves height and reads all cursor pages',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = DashboardServer('mik');
      await server.prepare();
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            home: Scaffold(body: RemoteHomeInvoices(onMore: () async {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('7 روز گذشته (مجموعا 2 فاکتور)'), findsOneWidget);
      expect(find.text('آخرین فاکتورها'), findsOneWidget);
      expect(find.text('لغو/مرجوع'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
