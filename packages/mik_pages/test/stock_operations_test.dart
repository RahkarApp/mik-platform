import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/stock.dart';
import 'package:mik_pages/product/warehouse/stock_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'warehouse_management_test.dart' as previous;

const balanceId = '11111111-1111-4111-8111-111111111118';
const transferId = '22222222-2222-4222-8222-222222222228';
const movementId = '33333333-3333-4333-8333-333333333338';
const movementTwo = '44444444-4444-4444-8444-444444444448';

class StockServer extends previous.WarehouseServer {
  StockServer(super.app);
  bool denied = false,
      wrong = false,
      locked = false,
      drop = false,
      stale = false,
      badCursor = false;
  int physical = 10, damaged = 2, rev = 1, writes = 0;
  final stockReceipts = <String, Map<String, dynamic>>{};
  final posts = <http.Request>[];
  Map<String, dynamic> get buckets => {
    'onHand': '$physical',
    'damaged': '$damaged',
    'reserved': '1',
    'allocationPending': '1',
    'available': '${physical - damaged - 2}',
    'inbound': '10',
    'outbound': '0',
  };
  Map<String, dynamic> get balance => {
    'businessId': wrong ? 87654321 : 12345678,
    'warehouseId': warehouse,
    'balanceId': balanceId,
    'variantId': variantId,
    'productId': productId,
    'unitId': 1,
    'revision': rev,
    ...buckets,
  };
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/inventory-access/check')) {
      requests.add(request);
      if (denied) {
        return jsonResponse({
          'error': {'code': 'FORBIDDEN'},
        }, 403);
      }
      final body = jsonDecode(request.body) as Map;
      return jsonResponse({
        'allowed': true,
        'branchId': body['branchId'],
        'warehouseId': body['warehouseId'],
        'permissionCode': StockFX.permissions[body['operation']],
      });
    }
    if (path.endsWith('/inventory/stock')) {
      requests.add(request);
      expect(request.url.queryParameters['warehouseId'], warehouse);
      return jsonResponse({
        'businessId': 12345678,
        'warehouseId': warehouse,
        'blockedForCount': locked,
        'items': [balance],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/inventory/kardex')) {
      requests.add(request);
      final more = request.url.queryParameters['afterSequence'] != null;
      if (more) expect(request.url.queryParameters['throughSequence'], '5');
      return jsonResponse({
        'businessId': 12345678,
        'warehouseId': warehouse,
        'variantId': variantId,
        'throughSequence': 5,
        'opening': buckets,
        'closing': buckets,
        'items': [
          {
            'businessId': 12345678,
            'warehouseId': warehouse,
            'variantId': variantId,
            'movementId': more ? movementTwo : movementId,
            'sequence': more ? 4 : 2,
            'reason': 'ADJUSTMENT_IN',
            'createdAt': '2026-10-24T10:00:00.000Z',
            'before': buckets,
            'after': buckets,
            'deltas': {'deltaOnHand': '1'},
            'reference': {
              'type': 'ADJUSTMENT',
              'id': transferId,
              'reason': 'اصلاح واقعی',
            },
          },
        ],
        'nextSequence': more
            ? null
            : badCursor
            ? 1
            : 2,
      });
    }
    if (request.method == 'POST' && path.contains('/inventory/stock/')) {
      requests.add(request);
      posts.add(request);
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!;
      if (stockReceipts.containsKey(key)) {
        return jsonResponse(stockReceipts[key]!);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (stale) {
        return jsonResponse({
          'error': {'code': 'REVISION_CONFLICT'},
        }, 409);
      }
      final Map<String, dynamic> reply;
      final amount = int.parse(body['quantity'] as String);
      if (path.endsWith('/transfer')) {
        expect(body.keys.toSet(), {
          'fromWarehouseId',
          'toWarehouseId',
          'toBranchId',
          'variantId',
          'quantity',
          'condition',
          'reason',
        });
        physical -= amount;
        if (body['condition'] == 'DAMAGED') damaged -= amount;
        rev++;
        reply = {
          'businessId': 12345678,
          'transfer': {
            'businessId': 12345678,
            'revision': 1,
            'transferId': transferId,
            'branchId': branch,
            ...body,
          },
        };
      } else {
        expect(body['expectedRevision'], rev);
        expect(body['warehouseId'], warehouse);
        if (path.endsWith('/adjust')) {
          physical += body['direction'] == 'IN' ? amount : -amount;
        } else {
          damaged += body['action'] == 'QUARANTINE' ? amount : -amount;
          if (body['action'] == 'SCRAP') physical -= amount;
        }
        rev++;
        reply = {'businessId': 12345678, 'balance': balance};
      }
      writes++;
      stockReceipts[key] = reply;
      if (drop) {
        drop = false;
        throw TimeoutException('lost stock reply');
      }
      return jsonResponse(reply);
    }
    return super.respond(request);
  }

  Future<StockFX> client() async {
    await prepare();
    return StockFX(BusinessContext.forApp(app)!, warehouse);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var dir = Directory.current;
    while (!File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      dir = dir.parent;
    }
    await (FontLoader('ravi')..addFont(
          File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  });
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app stock snapshot, kardex pagination, tenant and permissions',
      () async {
        final server = StockServer(app);
        final fx = await server.client();
        final row = (await fx.balances()).items.single;
        expect(row.quantity('available'), '6');
        expect((await fx.kardex(row)).items.length, 2);
        server.badCursor = true;
        await expectLater(fx.kardex(row), throwsFormatException);
        server.wrong = true;
        await expectLater(fx.balances(), throwsFormatException);
        server.wrong = false;
        server.denied = true;
        await expectLater(fx.balances(), throwsA(isA<AuthError>()));
        expect(fx.context.selectedBranch!.branchId, branch);
        await expectLater(
          fx.send(
            StockCommand('adjust', {
              'warehouseId': warehouse,
              'variantId': variantId,
              'quantity': '1',
              'reason': 'اصلاح',
              'direction': 'OUT',
              'expectedRevision': row.revision,
            }, row),
          ),
          throwsA(isA<AuthError>()),
        );
        expect(server.writes, 0);
      },
    );
    test(
      '$app exact transfer replay and revision based adjust and condition',
      () async {
        final server = StockServer(app);
        var fx = await server.client();
        var row = (await fx.balances()).items.single;
        expect(
          (await fx.destinations(branch)).single.warehouseId,
          previous.extraWarehouse,
        );
        expect(fx.context.selectedBranch!.branchId, branch);
        server.drop = true;
        final transfer = StockCommand('transfer', {
          'fromWarehouseId': warehouse,
          'toWarehouseId': previous.extraWarehouse,
          'toBranchId': branch,
          'variantId': variantId,
          'quantity': '1',
          'condition': 'SELLABLE',
          'reason': 'انتقال واقعی',
        }, row);
        await expectLater(fx.send(transfer), throwsA(anything));
        fx = StockFX(fx.context, warehouse);
        await fx.restore();
        await fx.send(fx.pending!);
        expect(server.writes, 1);
        expect(server.posts.first.body, server.posts.last.body);
        expect(
          server.posts.first.headers['idempotency-key'],
          server.posts.last.headers['idempotency-key'],
        );
        for (final action in ['adjust', 'QUARANTINE', 'RESTORE', 'SCRAP']) {
          row = (await fx.balances()).items.single;
          final body = {
            'warehouseId': warehouse,
            'variantId': variantId,
            'quantity': '1',
            'expectedRevision': row.revision,
            'reason': 'عملیات واقعی',
            if (action == 'adjust') 'direction': 'IN' else 'action': action,
          };
          await fx.send(
            StockCommand(
              action == 'adjust' ? 'adjust' : 'condition',
              body,
              row,
            ),
          );
        }
        expect(server.physical, 9);
        expect(server.damaged, 1);
        expect(fx.pending, isNull);
        row = (await fx.balances()).items.single;
        server.stale = true;
        await expectLater(
          fx.send(
            StockCommand('adjust', {
              'warehouseId': warehouse,
              'variantId': variantId,
              'quantity': '1',
              'direction': 'OUT',
              'reason': 'اصلاح',
              'expectedRevision': row.revision,
            }, row),
          ),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'REVISION_CONFLICT'),
          ),
        );
        expect(fx.pending, isNull);
      },
    );
    testWidgets('$app native stock form confirms real condition change', (
      tester,
    ) async {
      tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = StockServer(app);
      await server.prepare();
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
      expect(server.writes, 0);
      await tester.tap(find.byKey(const ValueKey('stock-$balanceId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('وضعیت کالا'));
      await tester.pumpAndSettle();
      for (final entry in {
        'stock-quantity': '1',
        'stock-reason': 'آسیب واقعی کالا',
      }.entries) {
        final field = find.descendant(
          of: find.byKey(ValueKey(entry.key)),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      final submit = find.text('ثبت عملیات انبار');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(server.writes, 0);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text('بله'));
      await tester.tap(find.text('بله'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(server.damaged, 3);
      expect(find.text('عملیات انبار با موفقیت ثبت شد.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
