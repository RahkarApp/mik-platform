import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/testing.dart';
import 'package:mik_components/base/startup/start_app.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:mik_pages/invoice/read_controller.dart';
import 'package:mik_pages/realtime/host.dart';

import '../../mik_data/test/realtime_test.dart' show cursor, HostChannel;
import '../../mik_data/test/support/pim_fixtures.dart';
import 'invoice_read_test.dart' show InvoiceReadServer;
import '../../mik_data/test/support/onboarding_fixtures.dart'
    show jsonResponse, fixtureResult;

void main() {
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    testWidgets(
      '$app keeps live invoice updates after replacing the dashboard route',
      (tester) async {
        final channels = <HostChannel>[];
        final server = InvoiceReadServer(app)..empty = true;
        final invoices = InvoiceReadController(appId: app);
        addTearDown(invoices.onClose);
        // The app shell mounts before login and binds after branch selection.
        await tester.pumpWidget(
          StartApp(
            title: app,
            useSystemTheme: () => false,
            onGenerateRoute: (_) => null,
            appBuilder: (_, child) =>
                BusinessRealtimeHost(appId: app, builder: (_) => child!),
            home: BusinessRealtimeHost(
              appId: app,
              manageConnection: false,
              builder: (_) => const Scaffold(body: Text('dashboard')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = pimFixture(
          MockClient((request) async {
            if (request.url.path.endsWith('/authorization')) {
              return jsonResponse({
                ...fixtureAuthorization(['accounting.sale.read']),
                'scopeType': request.url.queryParameters['scopeType'],
                'scopeId': request.url.queryParameters['scopeId'],
              });
            }
            if (request.url.path.endsWith('/branches')) {
              return jsonResponse({
                'items': [fixtureResult()['branch']],
                'nextCursor': null,
              });
            }
            return jsonResponse({
              'businessId': 12345678,
              'items': server.empty ? [] : [server.summary('SALE')],
              'nextCursor': null,
            });
          }),
          appId: app,
        ).context;
        final realtime = RealtimeFX.forContext(
          context,
          connect: (_) {
            final channel = HostChannel();
            channels.add(channel);
            return channel;
          },
        );
        await context.selectBranch((await context.branches()).single);
        await tester.pumpAndSettle();
        expect(channels, hasLength(1));
        expect(channels.single.sent.single['type'], 'authenticate');
        await invoices.load();
        Get.offAll(
          () => Obx(
            () => Scaffold(body: Text('invoices: ${invoices.rows.length}')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('dashboard'), findsNothing);
        expect(find.text('invoices: 0'), findsOneWidget);
        expect(realtime.enabled.value, isTrue);
        server.empty = false;
        channels.single.incoming.add(
          jsonEncode({
            'type': 'changes',
            'cursor': cursor(1),
            'items': [
              {
                'eventId': '11111111-1111-4111-8111-111111111119',
                'resource': 'accounting.sale',
                'entityId': productId,
                'revision': 1,
                'occurredAt': '2026-10-25T10:00:00.000Z',
              },
            ],
          }),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(invoices.error.value, isNull);
        expect(channels.single.sent.last['type'], 'ack');
        expect(invoices.rows, hasLength(1));
        expect(find.text('invoices: 1'), findsOneWidget);
        expect(channels, hasLength(1));
        expect(channels.single.sent.last['type'], 'ack');
        BusinessContext.clear(app);
        await tester.pump();
        expect(realtime.enabled.value, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
