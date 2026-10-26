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
import 'package:http/testing.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/branches/controller.dart';
import 'package:mik_pages/branches/screen.dart';
import 'package:mik_pages/branches/fund_item.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const secondBranch = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const createdBranch = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

class BranchServer {
  final String app;
  BranchServer(this.app);
  final requests = <http.Request>[];
  final rows = <Map<String, dynamic>>[
    {
      ...(fixtureResult()['branch'] as Map<String, dynamic>),
      'code': '001',
      'address': {
        'countryCode': 'IR',
        'cityName': 'تهران',
        'fullAddress': 'آدرس اول',
      },
    },
    {
      ...(fixtureResult()['branch'] as Map<String, dynamic>),
      'branchId': secondBranch,
      'name': 'شعبه دوم',
      'code': '002',
    },
  ];
  final receipts = <String, Map<String, dynamic>>{};
  bool write = true, lost = false, conflict = false, wrongBusiness = false;
  bool fundsAllowed = true, wrongFundBranch = false;
  Completer<http.Response>? delayed;
  List<http.Request> get writes =>
      requests.where((r) => r.method != 'GET').toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final scope = request.url.queryParameters['scopeType'];
      return jsonResponse({
        ...fixtureAuthorization([
          'business.branch.read',
          if (fundsAllowed) 'accounting.treasury.read',
          if (write && scope == 'BUSINESS') 'business.branch.create',
          if (write && (app == 'mik' || scope == 'BRANCH'))
            'business.branch.update',
        ]),
        'scopeType': scope,
        'scopeId': request.url.queryParameters['scopeId'],
      });
    }
    if (path.endsWith('/accounting/treasury/funds')) {
      expect(request.method, 'GET');
      expect(
        request.url.queryParameters.keys.toSet().difference({
          'kind',
          'limit',
          'after',
        }),
        isEmpty,
      );
      final selected = request.headers['x-branch-id']!;
      final kind = request.url.queryParameters['kind']!;
      expect(['CASH', 'PETTY_CASH'], contains(kind));
      final more = request.url.queryParameters['after'] != null;
      final id = kind == 'CASH'
          ? more
                ? createdBranch
                : secondBranch
          : branch;
      return jsonResponse({
        'businessId': 12345678,
        'items': selected == createdBranch
            ? []
            : [
                {
                  'fundId': id,
                  'businessId': 12345678,
                  'branchId': wrongFundBranch ? branch : selected,
                  'name': kind == 'CASH'
                      ? more
                            ? 'صندوق دوم'
                            : 'صندوق اول'
                      : 'تنخواه شعبه',
                  'kind': kind,
                  'status': more ? 'ARCHIVED' : 'ACTIVE',
                  'balance': 1000,
                  'availableAmount': 800,
                },
              ],
        'nextCursor': selected != createdBranch && kind == 'CASH' && !more
            ? secondBranch
            : null,
      });
    }
    expect(path, startsWith('/v1/businesses/12345678/branches'));
    if (request.method == 'GET') {
      if (path.endsWith('/branches')) {
        expect(
          request.url.queryParameters.keys.toSet().difference({
            'after',
            'limit',
          }),
          isEmpty,
        );
        if (delayed != null) return delayed!.future;
        return jsonResponse({
          'items': request.url.queryParameters['after'] == null
              ? [rows.first]
              : rows.skip(1).toList(),
          'nextCursor': request.url.queryParameters['after'] == null
              ? branch
              : null,
        });
      }
      return jsonResponse({
        'item': rows.singleWhere(
          (r) => r['branchId'] == request.url.pathSegments.last,
        ),
      });
    }
    expect(request.headers['x-app-id'], app);
    final key = request.headers['idempotency-key']!;
    if (receipts.containsKey(key)) return jsonResponse(receipts[key]!);
    if (conflict) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(
      body.keys.toSet().difference({'name', 'address', 'expectedRevision'}),
      isEmpty,
    );
    late Map<String, dynamic> row;
    if (request.method == 'POST') {
      row = {
        'branchId': createdBranch,
        'businessId': 12345678,
        'name': body['name'],
        'address': body['address'],
        'status': 'ACTIVE',
        'revision': 1,
        'defaultWarehouseId': null,
      };
      rows.add(row);
    } else {
      final index = rows.indexWhere(
        (r) => r['branchId'] == request.url.pathSegments.last,
      );
      expect(body['expectedRevision'], rows[index]['revision']);
      row = {
        ...rows[index],
        'name': body['name'],
        'address': body['address'],
        'revision': (rows[index]['revision'] as int) + 1,
      };
      rows[index] = row;
    }
    final result = {
      'businessId': 12345678,
      'item': wrongBusiness ? {...row, 'businessId': 87654321} : row,
    };
    receipts[key] = result;
    if (lost) {
      lost = false;
      throw TimeoutException('lost reply');
    }
    return jsonResponse(result);
  }

  Future<void> prepare() async {
    final context = pimFixture(MockClient(respond), appId: app).context;
    await context.selectBranch((await context.branches()).first);
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
      '$app branch pages and search are quiet; exact create retry and edit preserve address and selected branch',
      () async {
        final server = BranchServer(app);
        await server.prepare();
        final notices = <bool>[];
        final c = BranchManagementController(
          appId: app,
          onNotice: (_, s) => notices.add(s),
        );
        addTearDown(c.onClose);
        await c.load();
        expect(c.rows.length, 2);
        expect(notices, isEmpty);
        final funds = await c.fx!.funds(secondBranch);
        expect(funds.length, 3);
        expect(funds.map((f) => f.kind).toSet(), {'CASH', 'PETTY_CASH'});
        expect(funds.first.availableAmount, 800);
        expect(BusinessContext.forApp(app)!.selectedBranch!.branchId, branch);
        c.query.value = '۰۰۲';
        expect(c.visible.single.branchId, secondBranch);
        expect(await c.save('', ''), isNull);
        expect(server.writes, isEmpty);
        expect(notices.last, isFalse);
        server.lost = true;
        expect(await c.save('شعبه تازه', 'آدرس تازه'), isNull);
        expect(c.pending.value, isNotNull);
        final resumed = BranchManagementController(
          appId: app,
          onNotice: (_, s) => notices.add(s),
        );
        addTearDown(resumed.onClose);
        await resumed.load();
        expect((await resumed.save('تغییر نکند', ''))!.branchId, createdBranch);
        expect(server.rows.length, 3);
        expect(await resumed.fx!.funds(createdBranch), isEmpty);
        expect(server.writes.first.body, server.writes.last.body);
        expect(
          server.writes.first.headers['idempotency-key'],
          server.writes.last.headers['idempotency-key'],
        );
        final row = await resumed.details(branch);
        expect(resumed.fx!.canEdit(branch), isTrue);
        final result = await resumed.save('نام تازه', 'نشانی تازه', row: row);
        expect(result!.address!['cityName'], 'تهران');
        expect(result.address!['fullAddress'], 'نشانی تازه');
        expect(BusinessContext.forApp(app)!.selectedBranch!.name, 'نام تازه');
        expect(notices.last, isTrue);
      },
    );
    test(
      '$app branch denies scope, preserves revision conflict and rejects malformed and late results',
      () async {
        final server = BranchServer(app)..write = false;
        await server.prepare();
        final notices = <bool>[];
        final c = BranchManagementController(
          appId: app,
          onNotice: (_, s) => notices.add(s),
        );
        addTearDown(c.onClose);
        await c.load();
        expect(c.canCreate, isFalse);
        expect(await c.save('غیرمجاز', ''), isNull);
        expect(server.writes, isEmpty);
        server.write = true;
        await c.load();
        server.fundsAllowed = false;
        await expectLater(c.fx!.funds(secondBranch), throwsA(isA<Exception>()));
        server.fundsAllowed = true;
        server.wrongFundBranch = true;
        await expectLater(c.fx!.funds(secondBranch), throwsFormatException);
        server.wrongFundBranch = false;
        final row = await c.details(branch);
        server.conflict = true;
        expect(await c.save('قدیمی', '', row: row), isNull);
        expect(c.pending.value, isNull);
        expect(notices.last, isFalse);
        server.conflict = false;
        server.wrongBusiness = true;
        expect(await c.save('پاسخ نادرست', ''), isNull);
        expect(c.pending.value, isNotNull);
        expect(notices.last, isFalse);
        server.delayed = Completer<http.Response>();
        final before = server.requests.length;
        final loading = c.load();
        while (!server.requests
            .skip(before)
            .any((r) => r.url.path.endsWith('/branches'))) {
          await Future<void>.delayed(Duration.zero);
        }
        BusinessContext.clear(app);
        server.delayed!.complete(
          jsonResponse({'items': server.rows, 'nextCursor': null}),
        );
        await loading;
        expect(c.rows, isEmpty);
        expect(notices.last, isFalse);
      },
    );
    testWidgets(
      '$app branch list uses native FAB, Inputs and BTN with confirmed result Alert',
      (tester) async {
        final server = BranchServer(app);
        await server.prepare();
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
              home: BranchManagementScreen(appId: app),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('شعبه جدید'));
        await tester.pumpAndSettle();
        expect(find.byType(Input), findsNWidgets(2));
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('branch-name')),
            matching: find.byType(TextField),
          ),
          'شعبه تازه',
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('branch-address')),
            matching: find.byType(TextField),
          ),
          'آدرس تازه',
        );
        await tester.tap(find.text('افزودن شعبه'));
        await tester.pumpAndSettle();
        expect(find.text('شعبه تازه'), findsOneWidget);
        expect(find.text('شعبه جدید با موفقیت ایجاد شد.'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byKey(const ValueKey(secondBranch)));
        await tester.pumpAndSettle();
        expect(find.text('صندوق‌های شعبه'), findsOneWidget);
        expect(find.byType(BranchFundItem), findsNWidgets(3));
        expect(find.text('صندوق اول'), findsOneWidget);
        expect(find.text('تنخواه شعبه'), findsOneWidget);
        Get.back();
        await tester.pumpAndSettle();
        server.fundsAllowed = false;
        await tester.tap(find.byKey(const ValueKey(secondBranch)));
        await tester.pumpAndSettle();
        expect(find.byType(BranchFundItem), findsNothing);
        expect(
          find.text('مجوز مشاهده صندوق‌های این شعبه را ندارید.'),
          findsNWidgets(2),
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
