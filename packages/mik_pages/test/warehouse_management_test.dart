import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';
import 'package:toastification/toastification.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/branchInput.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/warehouse/controller.dart';
import 'package:mik_pages/product/warehouse/screen.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const otherBranch = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const otherBranchLink = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
const extraWarehouse = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const newWarehouse = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const linkId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const extraLink = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

class WarehouseServer {
  final String app;
  WarehouseServer(this.app);
  final requests = <http.Request>[];
  final warehouses = <Map<String, dynamic>>[
    Map<String, dynamic>.from(fixtureResult()['warehouse'] as Map),
    {
      ...Map<String, dynamic>.from(fixtureResult()['warehouse'] as Map),
      'warehouseId': extraWarehouse,
      'name': 'انبار دوم',
    },
  ];
  final branchRow = Map<String, dynamic>.from(fixtureResult()['branch'] as Map);
  final links = <Map<String, dynamic>>[
    {
      ...Map<String, dynamic>.from(fixtureResult()['branchAccess'] as Map),
      'branchAccessId': linkId,
    },
  ];
  final receipts = <String, Map<String, dynamic>>{};
  bool lost = false, conflict = false, warehouseWrite = true;
  bool includeOtherBranch = false;
  Completer<http.Response>? delayed;
  List<http.Request> get mutations =>
      requests.where((r) => r.method != 'GET').toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final scope = request.url.queryParameters['scopeType'];
      final permissions = scope == 'WAREHOUSE'
          ? [
              'business.warehouse.read',
              if (warehouseWrite) 'business.warehouse.update',
            ]
          : scope == 'BRANCH'
          ? ['business.branch.read', 'business.branch.update']
          : [
              'business.warehouse.read',
              'business.warehouse.create',
              if (warehouseWrite || app == 'mikyar')
                'business.warehouse.update',
              'business.branch.read',
              'business.branch.update',
              'business.branch-access.read',
              'business.branch-access.update',
            ];
      return jsonResponse({
        ...fixtureAuthorization(permissions),
        'scopeType': scope,
        'scopeId': request.url.queryParameters['scopeId'],
      });
    }
    if (path.endsWith('/branches')) {
      return jsonResponse({
        'items': [
          branchRow,
          if (includeOtherBranch)
            {...branchRow, 'branchId': otherBranch, 'name': 'شعبه دوم'},
        ],
        'nextCursor': null,
      });
    }
    if (request.method == 'GET') {
      if (path.endsWith('/warehouses')) {
        if (delayed != null) return delayed!.future;
        expect(
          request.url.queryParameters.keys.toSet().difference({
            'limit',
            'after',
          }),
          isEmpty,
        );
        return jsonResponse({
          'items': request.url.queryParameters['after'] == null
              ? [warehouses.first]
              : warehouses.skip(1).toList(),
          'nextCursor': request.url.queryParameters['after'] == null
              ? warehouse
              : null,
        });
      }
      if (includeOtherBranch && path.endsWith('/branches/$otherBranch')) {
        return jsonResponse({
          'item': {...branchRow, 'branchId': otherBranch, 'name': 'شعبه دوم'},
        });
      }
      if (path.endsWith('/branches/$branch')) {
        return jsonResponse({'item': branchRow});
      }
      if (path.endsWith('/branch-access')) {
        final target = request.url.queryParameters['branchId'];
        expect(target, isIn([branch, if (includeOtherBranch) otherBranch]));
        expect(request.headers['x-branch-id'], target);
        return jsonResponse({
          'items': links.where((l) => l['branchId'] == target).toList(),
          'nextCursor': null,
        });
      }
    }
    final key = request.headers['idempotency-key']!;
    if (receipts.containsKey(key)) return jsonResponse(receipts[key]!);
    if (conflict) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    final body = Map<String, dynamic>.from(jsonDecode(request.body));
    late Map<String, dynamic> item;
    if (path.endsWith('/warehouses') && request.method == 'POST') {
      expect(body.keys, ['name']);
      item = {
        ...warehouses.first,
        'warehouseId': newWarehouse,
        'name': body['name'],
      };
      warehouses.add(item);
    } else if (path.contains('/warehouses/')) {
      final index = warehouses.indexWhere(
        (w) => w['warehouseId'] == request.url.pathSegments.last,
      );
      expect(body['expectedRevision'], warehouses[index]['revision']);
      if (body['status'] != 'ACTIVE' &&
          branchRow['defaultWarehouseId'] == warehouses[index]['warehouseId']) {
        return jsonResponse({
          'error': {'code': 'DEFAULT_WAREHOUSE_UNAVAILABLE'},
        }, 409);
      }
      item = {
        ...warehouses[index],
        'name': body['name'],
        if (body['status'] != null) 'status': body['status'],
        'revision': (warehouses[index]['revision'] as int) + 1,
      };
      warehouses[index] = item;
    } else if (path.endsWith('/branch-access')) {
      expect(
        body['branchId'],
        isIn([branch, if (includeOtherBranch) otherBranch]),
      );
      expect(body['warehouseId'], extraWarehouse);
      item = {
        ...body,
        'branchAccessId': body['branchId'] == otherBranch
            ? otherBranchLink
            : extraLink,
        'businessId': 12345678,
        'revision': 1,
      };
      links.add(item);
    } else if (path.contains('/branch-access/')) {
      final index = links.indexWhere(
        (row) => row['branchAccessId'] == request.url.pathSegments.last,
      );
      expect(body['expectedRevision'], links[index]['revision']);
      if (branchRow['defaultWarehouseId'] == links[index]['warehouseId'] &&
          (body['status'] != 'ACTIVE' ||
              body['canReadStock'] != true ||
              body['canIssueStock'] != true)) {
        return jsonResponse({
          'error': {'code': 'DEFAULT_WAREHOUSE_UNAVAILABLE'},
        }, 409);
      }
      item = {
        ...links[index],
        ...body,
        'revision': (links[index]['revision'] as int) + 1,
      }..remove('expectedRevision');
      links[index] = item;
    } else if (path.endsWith('/branches/$branch')) {
      expect(body['expectedRevision'], branchRow['revision']);
      final link = links.singleWhere(
        (l) => l['warehouseId'] == body['defaultWarehouseId'],
      );
      expect(link['canReadStock'], isTrue);
      expect(link['canIssueStock'], isTrue);
      branchRow['defaultWarehouseId'] = body['defaultWarehouseId'];
      branchRow['revision'] = (branchRow['revision'] as int) + 1;
      item = branchRow;
    } else {
      throw StateError('Unexpected warehouse route: $path');
    }
    final result = {'businessId': 12345678, 'item': item, 'replayed': false};
    receipts[key] = result;
    if (lost) {
      lost = false;
      throw TimeoutException('reply lost');
    }
    return jsonResponse(result, request.method == 'POST' ? 201 : 200);
  }

  Future<void> prepare() async {
    final context = pimFixture(MockClient(respond), appId: app).context;
    await context.selectBranch((await context.branches()).single);
    requests.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var root = Directory.current;
    while (!File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
            .existsSync() &&
        root.parent.path != root.path) {
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
    toastification.dismissAll(delayForAnimation: false);
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app paginated search, create retry and revision-aware scoped rename',
      () async {
        final server = WarehouseServer(app);
        await server.prepare();
        final c = WarehouseManagementController();
        addTearDown(c.onClose);
        await c.attach(app);
        expect(c.error.value, isNull);
        expect(c.items.length, 2);
        c.search('دوم');
        expect(c.visible.single.warehouseId, extraWarehouse);
        c.search('');
        server.lost = true;
        expect(await c.rename('انبار تازه'), isFalse);
        expect(c.pending.value, isNotNull);
        final resumed = WarehouseManagementController();
        addTearDown(resumed.onClose);
        await resumed.attach(app);
        expect(await resumed.resume(), isTrue);
        expect(server.warehouses.length, 3);
        expect(server.mutations.length, 2);
        expect(server.mutations[0].body, server.mutations[1].body);
        expect(
          server.mutations[0].headers['idempotency-key'],
          server.mutations[1].headers['idempotency-key'],
        );
        final row = resumed.items.singleWhere(
          (w) => w.warehouseId == newWarehouse,
        );
        await resumed.prepare(row);
        expect(resumed.canEdit(row), isTrue);
        expect(await resumed.rename('نام اصلاح‌شده', item: row), isTrue);
        expect(server.mutations.last.method, 'PATCH');
        final updated = resumed.items.singleWhere(
          (w) => w.warehouseId == newWarehouse,
        );
        expect(
          await resumed.rename(updated.name, item: updated, status: 'ARCHIVED'),
          isTrue,
        );
        expect(
          resumed.items
              .singleWhere((w) => w.warehouseId == newWarehouse)
              .status,
          'ARCHIVED',
        );
        expect(server.mutations.last.headers['x-app-id'], app);
        expect(server.mutations.last.headers['x-branch-id'], branch);
        expect(
          jsonDecode(server.mutations.last.body)['expectedRevision'],
          updated.revision,
        );
      },
    );
    test(
      '$app links the same warehouse to another branch without changing the active branch',
      () async {
        final server = WarehouseServer(app);
        await server.prepare();
        server.includeOtherBranch = true;
        final c = WarehouseManagementController();
        addTearDown(c.onClose);
        await c.attach(app);
        final row = c.items.singleWhere((w) => w.warehouseId == extraWarehouse);
        expect(
          await c.connect(row, read: true, receive: true, issue: true),
          isTrue,
        );
        await c.attach(app, branchId: otherBranch);
        expect(c.error.value, isNull);
        expect(c.branch.value!.branchId, otherBranch);
        expect(c.link(row), isNull);
        expect(
          await c.connect(row, read: true, receive: false, issue: true),
          isTrue,
        );
        expect(jsonDecode(server.mutations.last.body)['branchId'], otherBranch);
        expect(server.mutations.last.headers['x-branch-id'], otherBranch);
        expect(
          server.links.where((l) => l['warehouseId'] == extraWarehouse),
          hasLength(2),
        );
        expect(BusinessContext.forApp(app)!.selectedBranch!.branchId, branch);
        await c.attach(app);
        expect(c.link(row)!.canReceiveStock, isTrue);
        expect(BusinessContext.forApp(app)!.selectedBranch!.branchId, branch);
      },
    );
    test(
      '$app links explicit read/receive/issue grants before setting default and refreshes selected branch',
      () async {
        final server = WarehouseServer(app);
        await server.prepare();
        final c = WarehouseManagementController();
        addTearDown(c.onClose);
        await c.attach(app);
        final row = c.items.singleWhere((w) => w.warehouseId == extraWarehouse);
        expect(c.canDefault(row), isFalse);
        expect(await c.setDefault(row), isFalse);
        expect(server.mutations, isEmpty);
        expect(
          await c.connect(row, read: true, receive: true, issue: true),
          isTrue,
        );
        expect(jsonDecode(server.mutations.single.body), {
          'branchId': branch,
          'warehouseId': extraWarehouse,
          'canReadStock': true,
          'canReceiveStock': true,
          'canIssueStock': true,
          'status': 'ACTIVE',
        });
        expect(
          await c.connect(
            row,
            read: true,
            receive: true,
            issue: true,
            status: 'SUSPENDED',
          ),
          isTrue,
        );
        expect(c.link(row)!.status, 'SUSPENDED');
        expect(c.canDefault(row), isFalse);
        expect(
          await c.connect(row, read: true, receive: true, issue: true),
          isTrue,
        );
        expect(c.canDefault(row), isTrue);
        expect(await c.setDefault(row), isTrue);
        expect(
          BusinessContext.forApp(app)!.selectedBranch!.defaultWarehouseId,
          extraWarehouse,
        );
        expect(c.branch.value!.revision, 2);
        expect(
          await c.connect(
            row,
            read: true,
            receive: false,
            issue: true,
            status: 'SUSPENDED',
          ),
          isFalse,
        );
        expect(c.commandError.value, contains('پیش‌فرض'));
        expect(c.link(row)!.status, 'ACTIVE');
        expect(c.pending.value, isNull);
      },
    );
    test(
      '$app refuses wrong-scope rename, blocks revision conflict and drops late data after branch change',
      () async {
        final server = WarehouseServer(app)..warehouseWrite = false;
        await server.prepare();
        final c = WarehouseManagementController();
        addTearDown(c.onClose);
        await c.attach(app);
        var row = c.items.first;
        await c.prepare(row);
        expect(c.canEdit(row), isFalse);
        expect(await c.rename('غیرمجاز', item: row), isFalse);
        expect(server.mutations, isEmpty);
        server.warehouseWrite = true;
        await c.load();
        row = c.items.first;
        await c.prepare(row);
        server.conflict = true;
        expect(await c.rename('نسخه قدیمی', item: row), isFalse);
        expect(c.conflict.value, isTrue);
        final count = server.mutations.length;
        expect(await c.rename('تلاش بی‌اعتبار', item: row), isFalse);
        expect(server.mutations.length, count);
        server.conflict = false;
        server.delayed = Completer<http.Response>();
        final before = server.requests
            .where((r) => r.url.path.endsWith('/warehouses'))
            .length;
        final loading = c.load();
        while (server.requests
                .where((r) => r.url.path.endsWith('/warehouses'))
                .length ==
            before) {
          await Future<void>.delayed(Duration.zero);
        }
        BusinessContext.forApp(app)!.clearAccess();
        server.delayed!.complete(
          jsonResponse({'items': server.warehouses, 'nextCursor': null}),
        );
        await loading;
        expect(c.items, isEmpty);
        expect(c.error.value, isNotNull);
      },
    );
    testWidgets(
      '$app warehouse tab uses native create and link controls without guessed stock',
      (tester) async {
        final server = WarehouseServer(app);
        await server.prepare();
        server.includeOtherBranch = true;
        final c = WarehouseManagementController();
        addTearDown(c.onClose);
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: Scaffold(
                body: WarehouseManagementScreen(appId: app, controller: c),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('اقلام: نامشخص'), findsNWidgets(2));
        await tester.tap(find.text('انبار جدید'));
        await tester.pumpAndSettle();
        expect(find.byType(Input), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('warehouse-name')),
            matching: find.byType(TextField),
          ),
          'انبار تازه',
        );
        await tester.tap(find.text('افزودن انبار'));
        await tester.pumpAndSettle();
        expect(find.text('انبار تازه'), findsOneWidget);
        expect(find.text('عملیات انبار با موفقیت انجام شد.'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('انبار دوم'));
        await tester.pumpAndSettle();
        expect(find.byType(MiniBTN), findsWidgets);
        await tester.tap(find.text('اتصال به شعبه'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BranchInput));
        await tester.pumpAndSettle();
        await tester.tap(find.text('شعبه دوم'));
        await tester.pumpAndSettle();
        expect(c.branch.value!.branchId, otherBranch);
        for (final title in ['مشاهده موجودی', 'ورود کالا', 'خروج کالا']) {
          await tester.tap(find.text('$title: غیرمجاز'));
          await tester.pumpAndSettle();
        }
        expect(
          tester
              .widgetList<BTN>(find.byType(BTN))
              .any((b) => b.name == 'ثبت اتصال'),
          isTrue,
        );
        await tester.tap(find.text('ثبت اتصال'));
        await tester.pumpAndSettle();
        expect(server.links.length, 2);
        expect(server.links.last['branchId'], otherBranch);
        expect(BusinessContext.forApp(app)!.selectedBranch!.branchId, branch);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
