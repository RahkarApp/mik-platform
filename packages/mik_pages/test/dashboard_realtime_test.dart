import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:mik_pages/dashboard/profit_chart.dart';
import 'package:mik_pages/dashboard/invoices.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/realtime_test.dart' show SocketServer, until;
import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'dashboard_read_test.dart' show DashboardServer;

class LiveDashboardServer extends DashboardServer {
  LiveDashboardServer(super.app);
  int invoiceReads = 0;
  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/v2/invoices')) invoiceReads++;
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
    testWidgets(
      '$app dashboard chart refreshes authorized events and preserves month selection',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = DashboardServer(app);
        final context = await server.prepare();
        final socket = SocketServer();
        late RealtimeFX realtime;
        await tester.runAsync(() async {
          await socket.open();
          realtime = RealtimeFX.forContext(
            context,
            connect: socket.connect,
            retryDelay: const Duration(milliseconds: 10),
          );
          await realtime.start();
          await until(() => socket.auths.isNotEmpty);
        });
        addTearDown(() async {
          realtime.stop();
          await socket.close();
        });
        var saved = 0;
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              home: Scaffold(
                body: RemoteProfitHomeChart(
                  appId: app,
                  height: 200,
                  initialPeriod: 'سود ماه',
                  onPeriodChanged: (_) async {
                    saved++;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('سود این ماه'), findsOneWidget);
        final before = server.profitCalls;
        server.complete = false;
        await tester.runAsync(() async {
          socket.changes(1, resource: 'accounting.stock-cost');
          await until(() => socket.acks.isNotEmpty);
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(server.profitCalls, greaterThan(before));
        expect(find.textContaining('بخشی از سود'), findsOneWidget);
        expect(find.text('سود این ماه'), findsOneWidget);
        expect(tester.getSize(find.byType(SfCartesianChart)).height, 200);
        expect(saved, 0);
        server.allowReports = false;
        await tester.runAsync(() async {
          await socket.resync(1, reason: 'ACCESS_CHANGED');
          await until(() => socket.auths.length == 2);
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.byType(SfCartesianChart), findsNothing);
        expect(find.textContaining('مجوز مشاهده'), findsWidgets);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'Mik dashboard invoice burst reloads once and preserves selected day range',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = LiveDashboardServer('mik');
      final context = await server.prepare();
      final socket = SocketServer();
      late RealtimeFX realtime;
      await tester.runAsync(() async {
        await socket.open();
        realtime = RealtimeFX.forContext(context, connect: socket.connect);
        await realtime.start();
        await until(() => socket.auths.isNotEmpty);
      });
      addTearDown(() async {
        realtime.stop();
        await socket.close();
      });
      var saved = 0;
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            home: Scaffold(
              body: RemoteHomeInvoices(
                initialDays: 30,
                onMore: () async {},
                onDaysChanged: (_) async {
                  saved++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = server.invoiceReads;
      expect(find.text('30 روز گذشته (مجموعا 2 فاکتور)'), findsOneWidget);
      await tester.runAsync(() async {
        socket.changes(1, resource: 'accounting.sale');
        socket.changes(2, resource: 'accounting.payment');
        await until(() => socket.acks.length == 2);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('30 روز گذشته (مجموعا 2 فاکتور)'), findsOneWidget);
      expect(server.invoiceReads, before * 2);
      expect(saved, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
