import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/permission.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/personnel.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/personnel/controller.dart';
import 'package:mik_pages/personnel/screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const personId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const memberId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const roleId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const grantId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

class PersonnelServer {
  final String app;
  PersonnelServer(this.app);
  final permissions = <String>{
    'business.personnel.read',
    'business.personnel.create',
    'business.personnel.update',
    'business.role.read',
    'business.role.update',
    'business.personnel.access.update',
  };
  final people = <Map<String, dynamic>>[];
  final roles = <Map<String, dynamic>>[
    {
      'roleId': roleId,
      'businessId': 12345678,
      'name': 'فروشنده',
      'permissionCodes': ['business.personnel.read'],
      'status': 'ACTIVE',
      'revision': 1,
    },
  ];
  final grants = <Map<String, dynamic>>[];
  final writes = <http.Request>[];
  final receipts = <String, Map<String, dynamic>>{};
  bool lost = false,
      conflict = false,
      wrongBusiness = false,
      extraBranch = false;
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      return jsonResponse({
        ...fixtureAuthorization(permissions),
        'scopeType': request.url.queryParameters['scopeType'],
        'scopeId': request.url.queryParameters['scopeId'],
      });
    }
    if (path.endsWith('/branches')) {
      return jsonResponse({
        'items': [
          fixtureResult()['branch'],
          if (extraBranch)
            {
              ...fixtureResult()['branch'] as Map<String, dynamic>,
              'branchId': grantId,
            },
        ],
        'nextCursor': null,
      });
    }
    expect(request.headers['x-app-id'], app);
    if (path == '/v1/permissions') {
      return jsonResponse({
        'version': 1,
        'permissions': [
          {
            'code': 'business.personnel.read',
            'domain': 'business',
            'resource': 'personnel',
            'title': 'مشاهده پرسنل',
          },
        ],
      });
    }
    expect(path, startsWith('/v1/businesses/12345678/'));
    final resource = path.contains('/personnel')
        ? PersonnelResource.person
        : path.contains('/roles')
        ? PersonnelResource.role
        : PersonnelResource.access;
    final rows = switch (resource) {
      PersonnelResource.person => people,
      PersonnelResource.role => roles,
      PersonnelResource.access => grants,
    };
    if (request.method == 'GET') {
      if (path.endsWith('/${resource.path}')) {
        expect(request.url.queryParameters['limit'], '100');
        final membership = request.url.queryParameters['membershipId'];
        return jsonResponse({
          'items': rows
              .where(
                (row) =>
                    membership == null || row['membershipId'] == membership,
              )
              .toList(),
          'nextCursor': null,
        });
      }
      return jsonResponse({
        'item': rows.singleWhere(
          (row) => row[resource.idField] == request.url.pathSegments.last,
        ),
      });
    }
    writes.add(request);
    final key = request.headers['idempotency-key']!;
    if (receipts.containsKey(key)) {
      return jsonResponse({...receipts[key]!, 'replayed': true});
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final update = request.method == 'PATCH';
    Map<String, dynamic>? before;
    if (update) {
      before = rows.singleWhere(
        (row) => row[resource.idField] == request.url.pathSegments.last,
      );
      if (conflict || before['revision'] != body['expectedRevision']) {
        return jsonResponse({
          'error': {'code': 'REVISION_CONFLICT'},
        }, 409);
      }
    }
    final row = <String, dynamic>{
      ...?before,
      'businessId': wrongBusiness ? 87654321 : 12345678,
      ...body,
      resource.idField:
          before?[resource.idField] ??
          switch (resource) {
            PersonnelResource.person => personId,
            PersonnelResource.role => personId,
            PersonnelResource.access =>
              rows.isEmpty ? grantId : 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
          },
      'revision': update ? (before!['revision'] as int) + 1 : 1,
    }..remove('expectedRevision');
    if (resource == PersonnelResource.person) {
      expect(
        body.keys.toSet().difference({
          'displayName',
          'personnelCode',
          'jobTitle',
          'employmentStatus',
          if (!update) 'phone',
          if (update) 'expectedRevision',
        }),
        isEmpty,
      );
      if (!update) expect(body['phone'], '09121234567');
      row.remove('phone');
      row.addAll({
        'membershipId': memberId,
        'startedAt': before?['startedAt'] ?? '2026-10-23T10:00:00.000Z',
        'employmentStatus':
            body['employmentStatus'] ?? before?['employmentStatus'] ?? 'ACTIVE',
        'endedAt': body['employmentStatus'] == 'ENDED'
            ? '2026-10-23T12:00:00.000Z'
            : null,
      });
    } else {
      row['status'] ??= 'ACTIVE';
      if (resource == PersonnelResource.access && update) {
        expect(body.keys.toSet(), {'roleIds', 'status', 'expectedRevision'});
      }
    }
    if (before == null) {
      rows.add(row);
    } else {
      rows[rows.indexOf(before)] = row;
    }
    final result = <String, dynamic>{
      'businessId': 12345678,
      'item': row,
      'replayed': false,
      if (resource == PersonnelResource.person)
        'membership': {
          'businessId': 12345678,
          'membershipId': memberId,
          'personnelId': personId,
          'membershipType': 'PERSONNEL',
          'status': {
            'ACTIVE': 'ACTIVE',
            'SUSPENDED': 'SUSPENDED',
            'ENDED': 'REMOVED',
          }[row['employmentStatus']],
        },
    };
    receipts[key] = result;
    if (lost) {
      lost = false;
      throw TimeoutException('lost reply');
    }
    return jsonResponse(result, update ? 200 : 201);
  }

  Future<void> prepare() async {
    final context = pimFixture(MockClient(respond), appId: app).context;
    await context.selectBranch((await context.branches()).single);
  }
}

class PersonnelAssets extends CachingAssetBundle {
  final String root;
  PersonnelAssets(this.root);
  @override
  Future<ByteData> load(String key) =>
      key == 'assets/images/icon/svg/mikyar.svg'
      ? File('$root/mik-app/$key').readAsBytes().then(ByteData.sublistView)
      : rootBundle.load(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String root;
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var directory = Directory.current;
    while (!File('${directory.path}/mik-app/assets/fonts/RaviLight.ttf')
            .existsSync() &&
        directory.parent.path != directory.path) {
      directory = directory.parent;
    }
    root = directory.path;
    await (FontLoader('ravi')..addFont(
          File('$root/mik-app/assets/fonts/RaviLight.ttf')
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
      '$app personnel exact retry, membership status, role permissions and scoped grants',
      () async {
        final server = PersonnelServer(app);
        await server.prepare();
        final notices = <bool>[];
        final c = PersonnelController(
          appId: app,
          onNotice: (_, ok) => notices.add(ok),
        );
        addTearDown(c.onClose);
        await c.load();
        expect(notices, isEmpty);
        server.permissions.remove('business.personnel.create');
        await c.load();
        expect(
          await c.save(PersonnelResource.person, {
            'displayName': 'ممنوع',
            'phone': '09121234567',
          }),
          isNull,
        );
        expect(server.writes, isEmpty);
        server.permissions.add('business.personnel.create');
        server.lost = true;
        expect(
          await c.save(PersonnelResource.person, {
            'displayName': 'پرسنل نمونه',
            'phone': '09121234567',
          }),
          isNull,
        );
        expect(c.pending.value, isNotNull);
        final resumed = PersonnelController(
          appId: app,
          onNotice: (_, ok) => notices.add(ok),
        );
        addTearDown(resumed.onClose);
        await resumed.load();
        final item = (await resumed.save(PersonnelResource.person, {}))!;
        expect(server.people.length, 1);
        expect(server.writes[0].body, server.writes[1].body);
        expect(
          server.writes[0].headers['idempotency-key'],
          server.writes[1].headers['idempotency-key'],
        );
        expect(item.data.containsKey('phone'), isFalse);
        final suspended = (await resumed.save(PersonnelResource.person, {
          'displayName': item.name,
          'employmentStatus': 'SUSPENDED',
        }, item: item))!;
        expect(suspended.status, 'SUSPENDED');
        server.conflict = true;
        expect(
          await resumed.save(PersonnelResource.person, {
            'displayName': 'تداخل',
          }, item: suspended),
          isNull,
        );
        expect(resumed.pending.value, isNull);
        expect(resumed.error.value, contains('نسخه جدید'));
        server.conflict = false;
        final ended = (await resumed.save(PersonnelResource.person, {
          'displayName': item.name,
          'employmentStatus': 'ENDED',
        }, item: suspended))!;
        expect(ended.status, 'ENDED');
        resumed.tab.value = 1;
        await resumed.load();
        expect(
          (await resumed.fx!.catalog()).single['code'],
          'business.personnel.read',
        );
        final role = (await resumed.save(PersonnelResource.role, {
          'name': 'نقش جدید',
          'permissionCodes': ['business.personnel.read'],
          'status': 'ACTIVE',
        }))!;
        final grant = (await resumed.save(PersonnelResource.access, {
          'membershipId': memberId,
          'scopeType': 'BRANCH',
          'scopeId': branch,
          'roleIds': [role.id],
          'status': 'ACTIVE',
        }))!;
        expect(
          (await resumed.fx!.list(
            PersonnelResource.access,
            membershipId: memberId,
          )).single.id,
          grant.id,
        );
        final disabled = (await resumed.save(PersonnelResource.access, {
          'roleIds': [],
          'status': 'SUSPENDED',
        }, item: grant))!;
        expect(disabled.status, 'SUSPENDED');
        server.permissions.remove('business.role.read');
        await resumed.load();
        expect(resumed.rows, isEmpty);
        expect(notices.last, isFalse);
        final context = BusinessContext.forApp(app)!;
        server.extraBranch = true;
        await context.selectBranch((await context.branches()).last);
        await resumed.load();
        expect(resumed.error.value, contains('شعبه تغییر کرده'));
        final reopened = PersonnelController(
          appId: app,
          onNotice: (_, ok) => notices.add(ok),
        );
        addTearDown(reopened.onClose);
        await reopened.load();
        expect(reopened.error.value, isNull);
        expect(reopened.rows.single.id, personId);
      },
    );

    testWidgets(
      '$app native personnel creation, role catalog and explicit access assignment',
      (tester) async {
        final server = PersonnelServer(app);
        await server.prepare();
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ToastificationWrapper(
            child: DefaultAssetBundle(
              bundle: PersonnelAssets(root),
              child: GetMaterialApp(
                onGenerateRoute: navigation.MikRouter(
                  sharedRoutes: SharedRoutes.namedPages,
                ).generateRoute,
                theme: ThemeData(fontFamily: 'ravi'),
                home: PersonnelScreen(appId: app, initialCreate: app == 'mik'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (app == 'mikyar') {
          await tester.tap(find.text('میک‌یار جدید'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('ثبت'));
        await tester.pumpAndSettle();
        expect(server.writes, isEmpty);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpAndSettle();
        for (final field in {
          'name': 'پرسنل نمونه',
          'phone': '۰۹۱۲۱۲۳۴۵۶۷',
        }.entries) {
          await tester.enterText(
            find.descendant(
              of: find.byKey(ValueKey('personnel-${field.key}')),
              matching: find.byType(TextField),
            ),
            field.value,
          );
        }
        await tester.tap(
          find.text(app == 'mik' ? 'ثبت و تعیین سطح دسترسی' : 'ثبت'),
        );
        await tester.pumpAndSettle();
        expect(find.text('اطلاعات با موفقیت ثبت شد.'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        expect(server.grants, isEmpty);
        if (app == 'mikyar') {
          await tester.tap(
            find.byKey(const ValueKey('personnel-access-$personId')),
          );
          await tester.pumpAndSettle();
        }
        expect(
          find.text('برای این محدوده سطح دسترسی ثبت نشده است.'),
          findsOneWidget,
        );
        await tester.tap(find.text('ثبت دسترسی'));
        await tester.pumpAndSettle();
        expect(server.grants, isEmpty);
        expect(find.text('حداقل یک سطح دسترسی انتخاب کنید.'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('فروشنده'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ثبت دسترسی'));
        await tester.pumpAndSettle();
        expect(server.grants.single['scopeType'], 'BUSINESS');
        expect(server.grants.single['membershipId'], memberId);
        expect(server.grants.single['roleIds'], [roleId]);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(
          find.byKey(const ValueKey('personnel-access-$personId')),
        );
        await tester.pumpAndSettle();
        expect(find.text('دسترسی فعلی: فروشنده (فعال)'), findsOneWidget);
        await tester.tap(find.text('شعبه'));
        await tester.pumpAndSettle();
        expect(BusinessContext.forApp(app)!.selectedBranch!.branchId, branch);
        await tester.tap(
          find.text((fixtureResult()['branch'] as Map)['name'] as String),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('فروشنده'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('سطح دسترسی جدید'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('personnel-name')),
            matching: find.byType(TextField),
          ),
          'نقش جدید',
        );
        expect(find.byType(PermissionSection), findsOneWidget);
        expect(find.text('تعداد: 0/1'), findsOneWidget);
        await tester.ensureVisible(find.byType(PermissionSection));
        await tester.tap(find.text('میک‌یار'));
        await tester.pumpAndSettle();
        expect(find.byType(PermissionItem), findsOneWidget);
        await tester.tap(find.text('مشاهده پرسنل'));
        await tester.pumpAndSettle();
        expect(find.text('تعداد: 1/1'), findsOneWidget);
        await tester.tap(find.text('ثبت'));
        await tester.pumpAndSettle();
        expect(server.roles.last['permissionCodes'], [
          'business.personnel.read',
        ]);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('نقش جدید'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ثبت دسترسی'));
        await tester.pumpAndSettle();
        expect((server.grants.last['roleIds'] as List).toSet(), {
          roleId,
          personId,
        });
        expect(server.grants.last['scopeType'], 'BRANCH');
        expect(server.grants.last['scopeId'], branch);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('سطوح دسترسی'));
        await tester.pumpAndSettle();
        expect(find.text('نقش جدید'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
