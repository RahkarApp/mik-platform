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
import 'package:mik_data/utils/fx/stock_count.dart';
import 'package:mik_pages/product/warehouse/count_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'stock_operations_test.dart' as previous;

const countId = '55555555-5555-4555-8555-555555555558';

class CountServer extends previous.StockServer {
  CountServer(super.app);
  Map<String, dynamic>? count;
  int countWrites = 0;
  bool lostCount = false, conflictCount = false, wrongCount = false;
  final countReceipts = <String, Map<String, dynamic>>{};
  final countRequests = <http.Request>[];
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.contains('/inventory/counts')) {
      requests.add(request);
      if (request.method == 'GET') {
        final item = count == null
            ? null
            : {...count!, if (wrongCount) 'branchId': countId};
        if (path.endsWith('/counts')) {
          expect(request.url.queryParameters['warehouseIds'], warehouse);
          return jsonResponse({
            'businessId': 12345678,
            'items': item == null ? [] : [item],
            'nextCursor': null,
          });
        }
        return jsonResponse({'businessId': 12345678, 'item': item});
      }
      countRequests.add(request);
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!;
      if (countReceipts.containsKey(key)) {
        return jsonResponse(countReceipts[key]!);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (path.endsWith('/counts')) {
        expect(body.keys.toSet(), {'warehouseId', 'variantIds', 'reason'});
        if (locked) {
          return jsonResponse({
            'error': {'code': 'WAREHOUSE_COUNT_IN_PROGRESS'},
          }, 409);
        }
        count = {
          'businessId': 12345678,
          'countId': countId,
          'branchId': branch,
          'warehouseId': warehouse,
          'status': 'OPEN',
          'revision': 1,
          'reason': body['reason'],
          'createdAt': '2026-10-24T12:00:00.000Z',
          'lines': [
            <String, dynamic>{
              'variantId': variantId,
              'productId': productId,
              'unitId': 1,
              'active': true,
              'expectedRevision': rev,
              'onHand': '$physical',
              'damaged': '$damaged',
              'reserved': '1',
              'allocationPending': '1',
            },
          ],
        };
        locked = true;
      } else {
        if (conflictCount || body['expectedRevision'] != count!['revision']) {
          return jsonResponse({
            'error': {'code': 'REVISION_CONFLICT'},
          }, 409);
        }
        final lines = count!['lines'] as List;
        if (path.endsWith('/update')) {
          expect(body.keys.toSet(), {'countId', 'expectedRevision', 'lines'});
          for (final change in body['lines'] as List) {
            final row = lines.single as Map;
            expect(change.keys.toSet(), {
              'variantId',
              'countedOnHand',
              'countedDamaged',
            });
            row.addAll(Map<String, dynamic>.from(change as Map));
          }
        } else if (path.endsWith('/post')) {
          expect(body.keys.toSet(), {'countId', 'expectedRevision'});
          final row = lines.single as Map;
          if (!row.containsKey('countedOnHand') ||
              !row.containsKey('countedDamaged')) {
            return jsonResponse({
              'error': {'code': 'VALIDATION_FAILED'},
            }, 400);
          }
          final a = int.parse(row['countedOnHand'] as String),
              b = int.parse(row['countedDamaged'] as String);
          if (a - b < 2) {
            return jsonResponse({
              'error': {'code': 'HELD_STOCK_CONFLICT'},
            }, 409);
          }
          physical = a;
          damaged = b;
          rev++;
          locked = false;
          count!['status'] = 'POSTED';
        } else if (path.endsWith('/cancel')) {
          locked = false;
          count!['status'] = 'CANCELLED';
        }
        count!['revision'] = (count!['revision'] as int) + 1;
      }
      countWrites++;
      final response = jsonDecode(
        jsonEncode({'businessId': 12345678, 'count': count}),
      ) as Map<String, dynamic>;
      countReceipts[key] = response;
      if (lostCount) {
        lostCount = false;
        throw TimeoutException('lost count reply');
      }
      return jsonResponse(response);
    }
    return super.respond(request);
  }

  Future<StockCountFX> countClient() async => StockCountFX(await client());
  StockCountCommand get start => StockCountCommand('start', {
    'warehouseId': warehouse,
    'variantIds': [variantId],
    'reason': 'شمارش واقعی',
  });
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
      '$app durable start/update/post confirms count once and unlocks',
      () async {
        final server = CountServer(app);
        var fx = await server.countClient();
        server.lostCount = true;
        await expectLater(fx.send(server.start), throwsA(anything));
        expect(server.locked, isTrue);
        fx = StockCountFX(fx.stock);
        await fx.restore();
        var row = await fx.send(fx.pending!);
        expect(server.countWrites, 1);
        expect(row.lines.single.counted, isFalse);
        expect(server.countRequests.first.body, server.countRequests.last.body);
        expect(
          server.countRequests.first.headers['idempotency-key'],
          server.countRequests.last.headers['idempotency-key'],
        );
        row = await fx.send(
          StockCountCommand('update', {
            'countId': row.id,
            'expectedRevision': row.revision,
            'lines': [
              {
                'variantId': variantId,
                'countedOnHand': '9',
                'countedDamaged': '1',
              },
            ],
          }, before: row),
        );
        expect(server.physical, 10);
        expect(row.lines.single.difference('9', 'onHand'), '-1');
        server.lostCount = true;
        await expectLater(
          fx.send(
            StockCountCommand('post', {
              'countId': row.id,
              'expectedRevision': row.revision,
            }, before: row),
          ),
          throwsA(anything),
        );
        expect(server.locked, isFalse);
        fx = StockCountFX(fx.stock);
        await fx.restore();
        expect((await fx.send(fx.pending!)).status, 'POSTED');
        expect(server.countWrites, 3);
        expect(server.physical, 9);
        expect(server.damaged, 1);
        expect(fx.pending, isNull);
      },
    );
    test(
      '$app no implicit zero, held stock/revision conflict, cancel and scope',
      () async {
        final server = CountServer(app);
        final fx = await server.countClient();
        server.denied = true;
        await expectLater(fx.send(server.start), throwsA(isA<AuthError>()));
        expect(server.countWrites, 0);
        server.denied = false;
        var row = await fx.send(server.start);
        await expectLater(
          fx.send(
            StockCountCommand('post', {
              'countId': row.id,
              'expectedRevision': row.revision,
            }, before: row),
          ),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'VALIDATION_FAILED'),
          ),
        );
        row = await fx.send(
          StockCountCommand('update', {
            'countId': row.id,
            'expectedRevision': row.revision,
            'lines': [
              {
                'variantId': variantId,
                'countedOnHand': '0',
                'countedDamaged': '0',
              },
            ],
          }, before: row),
        );
        expect(row.lines.single.amount('countedOnHand'), '0');
        await expectLater(
          fx.send(
            StockCountCommand('post', {
              'countId': row.id,
              'expectedRevision': row.revision,
            }, before: row),
          ),
          throwsA(
            isA<AuthError>().having(
              (e) => e.code,
              'code',
              'HELD_STOCK_CONFLICT',
            ),
          ),
        );
        expect(server.locked, isTrue);
        server.conflictCount = true;
        await expectLater(
          fx.send(
            StockCountCommand('cancel', {
              'countId': row.id,
              'expectedRevision': row.revision,
            }, before: row),
          ),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'REVISION_CONFLICT'),
          ),
        );
        server.conflictCount = false;
        expect(
          (await fx.send(
            StockCountCommand('cancel', {
              'countId': row.id,
              'expectedRevision': row.revision,
            }, before: row),
          )).status,
          'CANCELLED',
        );
        expect(server.physical, 10);
        expect(server.locked, isFalse);
        server.wrongCount = true;
        await expectLater(fx.all(), throwsFormatException);
        expect(fx.stock.context.selectedBranch!.branchId, branch);
      },
    );
    testWidgets(
      '$app native count inputs start blank and require saved explicit values',
      (tester) async {
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = CountServer(app);
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: WarehouseCountScreen(
                appId: app,
                warehouse: BusinessWarehouse.fromJson(server.warehouses.first),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('شمارش جدید'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('count-select-$variantId')));
        final reason = find.descendant(
          of: find.byKey(const ValueKey('count-start-reason')),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(reason, 'شمارش واقعی');
        await tester.tap(find.text('بله'));
        await tester.ensureVisible(find.text('شروع شمارش'));
        await tester.tap(find.text('شروع شمارش'));
        await tester.pumpAndSettle();
        expect(server.locked, isTrue);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byKey(const ValueKey('count-$countId')));
        await tester.pumpAndSettle();
        for (final entry in {
          'count-physical-$variantId': '9',
          'count-damaged-$variantId': '1',
        }.entries) {
          final field = find.descendant(
            of: find.byKey(ValueKey(entry.key)),
            matching: find.byType(TextFormField),
          );
          expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);
          await tester.ensureVisible(field);
          await tester.enterText(field, entry.value);
        }
        await tester.ensureVisible(find.text('ثبت نهایی انبارگردانی'));
        await tester.tap(find.text('ثبت نهایی انبارگردانی'));
        await tester.pumpAndSettle();
        expect(server.countWrites, 1);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.ensureVisible(find.text('ذخیره مقادیر شمارش'));
        await tester.tap(find.text('ذخیره مقادیر شمارش'));
        await tester.pumpAndSettle();
        expect(server.physical, 10);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byKey(const ValueKey('count-$countId')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('بله'));
        await tester.tap(find.text('بله'));
        await tester.ensureVisible(find.text('ثبت نهایی انبارگردانی'));
        await tester.tap(find.text('ثبت نهایی انبارگردانی'));
        await tester.pumpAndSettle();
        expect(server.physical, 9);
        expect(server.locked, isFalse);
        expect(
          find.text(
            'انبارگردانی ثبت نهایی شد؛ موجودی اصلاح و قفل انبار آزاد شد.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
