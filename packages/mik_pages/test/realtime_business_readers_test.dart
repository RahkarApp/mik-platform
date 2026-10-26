import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:mik_pages/customers/customer_controller.dart';
import 'package:mik_pages/product/warehouse/stock_screen.dart';
import 'package:mik_pages/treasury/screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/realtime_test.dart' show SocketServer, until;
import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'customers_test.dart' as customers;
import 'stock_operations_test.dart' as stock;
import 'treasury_test.dart' as treasury;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var root = Directory.current;
    while (!File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      if (root.path == root.parent.path) throw StateError('Workspace missing');
      root = root.parent;
    }
    await (FontLoader('ravi')..addFont(
          File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  });
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app customer events preserve query/pages, defer edits and reject stale authorized replies',
      () async {
        final server = customers.CustomersServer(app);
        final context = pimFixture(
          MockClient(server.respond),
          appId: app,
        ).context;
        await context.selectBranch((await context.branches()).single);
        final socket = SocketServer();
        await socket.open();
        final realtime = RealtimeFX.forContext(
          context,
          connect: socket.connect,
          retryDelay: const Duration(milliseconds: 10),
        );
        final c = RemoteCustomersController(appId: app)..query = 'رضا';
        addTearDown(() async {
          c.onClose();
          realtime.stop();
          await socket.close();
        });
        await c.load();
        await c.load(more: true);
        expect(c.items.length, 2);
        await realtime.start();
        await until(() => socket.auths.isNotEmpty);
        c.editing = true;
        server.row = customers.customer(name: 'رضای تازه');
        final before = server.requests.length;
        socket.changes(1, resource: 'ucrm.customer');
        await until(() => socket.acks.isNotEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(server.requests.length, before);
        expect(c.items.first.name, 'رضا');
        c.editing = false;
        await until(
          () =>
              !c.loading.value &&
              c.items.length == 2 &&
              c.items.first.name == 'رضای تازه',
        );
        expect(c.query, 'رضا');
        final stale = Completer<http.Response>();
        server.listReply = stale;
        final listCount = server.requests
            .where((r) => r.url.path.endsWith('/customers'))
            .length;
        final previous = c.load();
        await until(
          () =>
              server.requests
                  .where((r) => r.url.path.endsWith('/customers'))
                  .length >
              listCount,
        );
        server.listReply = null;
        await socket.resync(1, reason: 'ACCESS_CHANGED');
        await until(
          () =>
              socket.auths.length == 2 &&
              !c.loading.value &&
              c.items.isNotEmpty,
        );
        stale.complete(
          jsonResponse({
            'businessId': 12345678,
            'items': [customers.customer(name: 'پاسخ قدیمی')],
            'nextCursor': null,
          }),
        );
        await previous;
        expect(c.items.any((row) => row.name == 'پاسخ قدیمی'), isFalse);
      },
    );
    testWidgets(
      '$app treasury events update reads and leave an open native form unchanged',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = treasury.TreasuryServer(app);
        final context = pimFixture(
          MockClient((request) async {
            if (request.url.path.endsWith('/branches')) {
              return jsonResponse({
                'items': [fixtureResult()['branch']],
                'nextCursor': null,
              });
            }
            return server.respond(request);
          }),
          appId: app,
        ).context;
        await context.selectBranch((await context.branches()).single);
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
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: TreasuryScreen(appId: app, branchId: branch),
            ),
          ),
        );
        await tester.pumpAndSettle();
        server.funds.first['name'] = 'صندوق تازه';
        await tester.runAsync(() async {
          socket.changes(1, resource: 'accounting.cash-fund');
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('صندوق تازه'), findsOneWidget);
        await tester.tap(find.text('افزودن صندوق'));
        await tester.pumpAndSettle();
        final input = tester.widget<Input>(find.byType(Input));
        input.controller.text = 'پیش‌نویس من';
        final before = server.requests.length;
        await tester.runAsync(() async {
          socket.changes(2, resource: 'accounting.cash-fund');
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        await tester.pumpAndSettle();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(input.controller.text, 'پیش‌نویس من');
        expect(server.requests.length, before);
        expect(server.writes, isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
    testWidgets(
      '$app stock event refreshes server availability without posting inventory',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = stock.StockServer(app);
        await server.prepare();
        final context = BusinessContext.forApp(app)!;
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
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: WarehouseStockScreen(
                appId: app,
                warehouse: BusinessWarehouse.fromJson(server.warehouses.first),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = server.requests
            .where((r) => r.url.path.endsWith('/inventory/stock'))
            .length;
        server.physical = 20;
        server.rev++;
        await tester.runAsync(() async {
          socket.changes(1, resource: 'inventory.balance');
          await Future<void>.delayed(const Duration(milliseconds: 450));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(
          server.requests
              .where((r) => r.url.path.endsWith('/inventory/stock'))
              .length,
          greaterThan(before),
        );
        expect(server.posts, isEmpty);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  }
}
