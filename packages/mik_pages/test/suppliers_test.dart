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
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:mik_pages/persons/supplier/server_controller.dart';
import 'package:mik_pages/persons/supplier/server_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const firstId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const secondId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const createdId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

class SupplierServer {
  final String app;
  final AccountingPersonType type;
  bool readAll = true, updateAll = true;
  SupplierServer(this.app, {this.type = AccountingPersonType.supplier}) {
    if (type != AccountingPersonType.supplier) {
      for (var i = 0; i < rows.length; i++) {
        rows[i][type.idField] = rows[i].remove('supplierId');
        if (type == AccountingPersonType.partner) {
          rows[i]['capitalBalance'] = 0;
          rows[i]['currentBalance'] = 0;
        }
        rows[i]['createdBy'] = {'identityId': i == 0 ? identity : createdId};
      }
    }
  }
  String get idField => type.idField;
  final requests = <http.Request>[];
  final rows = <Map<String, dynamic>>[
    {
      'supplierId': firstId,
      'name': 'بازرگانی اول',
      'phone': '02112345678',
      'businessId': 12345678,
      'revision': 1,
      'status': 'ACTIVE',
    },
    {
      'supplierId': secondId,
      'name': 'بازرگانی دوم',
      'businessId': 12345678,
      'revision': 1,
      'status': 'ACTIVE',
    },
  ];
  final receipts = <String, Map<String, dynamic>>{};
  bool wrongPartnerProfile = false;
  bool read = true,
      create = true,
      update = true,
      lost = false,
      wrongBusiness = false;
  Completer<http.Response>? delayed;
  List<http.Request> get writes =>
      requests.where((r) => r.method == 'POST').toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final scope = request.url.queryParameters['scopeType'];
      return jsonResponse({
        ...fixtureAuthorization([
          if (read) '${type.permission}.read',
          if (read && readAll && type == AccountingPersonType.serviceProvider)
            '${type.permission}.read.all',
          if (create) type.createPermission,
          if (update) ...[
            type.updatePermission,
            if (updateAll) '${type.permission}.update.all',
          ],
        ]),
        'scopeType': scope,
        'scopeId': request.url.queryParameters['scopeId'],
      });
    }
    if (path.endsWith('/branches')) {
      return jsonResponse({
        'items': [fixtureResult()['branch']],
        'nextCursor': null,
      });
    }
    expect(request.headers['x-app-id'], app);
    expect(request.headers['x-branch-id'], branch);
    expect(path, startsWith('/v1/businesses/12345678/accounting/'));
    if (request.method == 'GET' && path.endsWith('/${type.path}')) {
      expect(
        request.url.queryParameters.keys.toSet().difference({
          'limit',
          'after',
          'status',
        }),
        isEmpty,
      );
      expect(
        request.url.queryParameters['status'],
        isIn(['ACTIVE', 'ARCHIVED']),
      );
      expect(request.url.queryParameters['limit'], '100');
      if (delayed != null) return delayed!.future;
      final visibleRows = rows
          .where(
            (row) =>
                type != AccountingPersonType.serviceProvider ||
                app == 'mik' ||
                readAll ||
                (row['createdBy'] as Map?)?['identityId'] == identity,
          )
          .toList();
      return jsonResponse({
        'businessId': wrongBusiness ? 87654321 : 12345678,
        'items': request.url.queryParameters['status'] == 'ARCHIVED'
            ? visibleRows.where((r) => r['status'] == 'ARCHIVED').toList()
            : request.url.queryParameters['after'] == null
            ? visibleRows.take(1).where((r) => r['status'] == 'ACTIVE').toList()
            : visibleRows
                  .skip(1)
                  .where((r) => r['status'] == 'ACTIVE')
                  .toList(),
        'nextCursor':
            request.url.queryParameters['status'] == 'ACTIVE' &&
                request.url.queryParameters['after'] == null
            ? firstId
            : null,
      });
    }
    if (request.method == 'GET') {
      return jsonResponse({
        'businessId': 12345678,
        'item': rows.singleWhere(
          (r) => r[idField] == request.url.pathSegments.last,
        ),
      });
    }
    expect(request.method, 'POST');
    final key = request.headers['idempotency-key']!;
    if (receipts.containsKey(key)) {
      return jsonResponse({...receipts[key]!, 'replayed': true});
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final v2 = path.contains('/v2/');
    final updating = path.endsWith('/update');
    expect(
      path,
      '/v1/businesses/12345678/accounting/${v2 ? 'v2/' : ''}${type.path}${updating ? '/update' : ''}',
    );
    expect(
      body.keys.toSet().difference(
        v2
            ? {
                ...type.profileFields,
                if (updating) ...[idField, 'expectedRevision', 'status'],
              }
            : {'name', 'phone'},
      ),
      isEmpty,
    );
    if (updating &&
        rows.singleWhere((r) => r[idField] == body[idField])['revision'] !=
            body['expectedRevision']) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    if (type == AccountingPersonType.partner &&
        updating &&
        body['status'] == 'ARCHIVED' &&
        rows.singleWhere(
              (r) => r[idField] == body[idField],
            )['capitalBalance'] !=
            0) {
      return jsonResponse({
        'error': {'code': 'RECORD_IN_USE'},
      }, 409);
    }
    final row = <String, dynamic>{
      ...(updating
          ? rows.singleWhere((r) => r[idField] == body[idField])
          : {
              'businessId': 12345678,
              'status': 'ACTIVE',
              if (type == AccountingPersonType.partner) ...{
                'capitalBalance': 0,
                'currentBalance': 0,
              },
            }),
      ...body,
      idField: updating ? body[idField] : createdId,
      if (!updating && type == AccountingPersonType.serviceProvider)
        'createdBy': {'identityId': identity},
      'revision': updating ? (body['expectedRevision'] as int) + 1 : 1,
      if (v2) 'profileVersion': 2,
    }..remove('expectedRevision');
    if (updating) {
      rows[rows.indexWhere((r) => r[idField] == row[idField])] = row;
    } else {
      rows.add(row);
    }
    final result = {
      'businessId': 12345678,
      type.resultField: row,
      'replayed': false,
    };
    receipts[key] = result;
    if (lost) {
      lost = false;
      throw TimeoutException('reply lost');
    }
    if (wrongPartnerProfile && type == AccountingPersonType.partner) {
      wrongPartnerProfile = false;
      return jsonResponse({
        ...result,
        'partner': {...row, 'reference': 'WRONG'},
      }, 201);
    }
    return jsonResponse(result, 201);
  }

  Future<void> prepare() async {
    final context = pimFixture(MockClient(respond), appId: app).context;
    await context.selectBranch((await context.branches()).single);
    requests.clear();
  }
}

class SupplierAssets extends CachingAssetBundle {
  final String root;
  SupplierAssets(this.root);
  @override
  Future<ByteData> load(String key) =>
      [
        'assets/images/icon/svg/supplier.svg',
        'assets/images/icon/svg/servicer.svg',
        'assets/images/icon/svg/partner.svg',
      ].contains(key)
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
      '$app paginated local search, validation alerts and exact retry after lost reply',
      () async {
        final server = SupplierServer(app);
        await server.prepare();
        final notices = <(String, bool)>[];
        final c = SuppliersController(
          appId: app,
          onNotice: (m, s) => notices.add((m, s)),
        );
        addTearDown(c.onClose);
        await c.load();
        expect(notices, isEmpty);
        expect(c.items.length, 2);
        c.search('دوم');
        expect(c.visible.single.id, secondId);
        c.search('۰۲۱۱۲۳');
        expect(c.visible.single.id, firstId);
        notices.clear();
        expect(await c.create('', '09121234567', kind: 'PERSON'), isNull);
        expect(notices.single.$2, isFalse);
        notices.clear();
        expect(await c.create('تامین تازه', '   ', kind: 'PERSON'), isNull);
        expect(notices.single.$2, isFalse);
        for (final invalid in ['02112345678', '0912', '091212345678']) {
          notices.clear();
          expect(await c.create('تامین تازه', invalid, kind: 'PERSON'), isNull);
          expect(notices.single.$2, isFalse);
        }
        expect(server.writes, isEmpty);
        notices.clear();
        server.lost = true;
        expect(
          await c.create('تامین تازه', '۰۹۱۲۱۲۳۴۵۶۷', kind: 'PERSON'),
          isNull,
        );
        expect(notices.single.$2, isFalse);
        expect(c.pending.value, isNotNull);
        final resumed = SuppliersController(
          appId: app,
          onNotice: (m, s) => notices.add((m, s)),
        );
        addTearDown(resumed.onClose);
        await resumed.load();
        notices.clear();
        expect((await resumed.create('نباید جایگزین شود', ''))!.id, createdId);
        expect(notices.single.$2, isTrue);
        expect(resumed.pending.value, isNull);
        expect(server.rows.length, 3);
        expect(server.writes.length, 2);
        expect(server.writes.first.body, server.writes.last.body);
        expect(jsonDecode(server.writes.last.body), {
          'name': 'تامین تازه',
          'phone': '+989121234567',
          'kind': 'PERSON',
        });
        expect(
          server.writes.first.headers['idempotency-key'],
          server.writes.last.headers['idempotency-key'],
        );
      },
    );

    test(
      '$app rejects denied permissions, malformed business and late result after scope change',
      () async {
        final server = SupplierServer(app)
          ..read = false
          ..create = false;
        await server.prepare();
        final notices = <bool>[];
        final c = SuppliersController(
          appId: app,
          onNotice: (_, s) => notices.add(s),
        );
        addTearDown(c.onClose);
        await c.load();
        expect(c.canCreate, isFalse);
        expect(c.items, isEmpty);
        expect(notices.last, isFalse);
        expect(
          await c.create('غیرمجاز', '09121234567', kind: 'PERSON'),
          isNull,
        );
        expect(server.writes, isEmpty);
        server.read = server.create = true;
        server.wrongBusiness = true;
        await c.load();
        expect(c.items, isEmpty);
        expect(notices.last, isFalse);
        server.wrongBusiness = false;
        server.delayed = Completer<http.Response>();
        final before = server.requests.length;
        final loading = c.load();
        while (!server.requests
            .skip(before)
            .any((r) => r.url.path.endsWith('/${server.type.path}'))) {
          await Future<void>.delayed(Duration.zero);
        }
        BusinessContext.forApp(app)!.clearAccess();
        server.delayed!.complete(
          jsonResponse({
            'businessId': 12345678,
            'items': server.rows,
            'nextCursor': null,
          }),
        );
        await loading;
        expect(c.items, isEmpty);
        expect(notices.last, isFalse);
      },
    );

    test(
      '$app profile v2, legacy upgrade, revision conflict and exact update retry',
      () async {
        final server = SupplierServer(app);
        await server.prepare();
        final notices = <bool>[];
        final c = SuppliersController(
          appId: app,
          onNotice: (_, ok) => notices.add(ok),
        );
        addTearDown(c.onClose);
        await c.load();
        expect(
          c.items.first.kind,
          isNull,
        ); // Legacy records never get a guessed type.
        final old = c.items.first;
        server.update = false;
        await c.fx!.authorize();
        expect(c.canEdit(old), isFalse);
        expect(
          await c.create(old.name, '09121234567', kind: 'PERSON', item: old),
          isNull,
        );
        expect(server.writes, isEmpty);
        server.update = true;
        await c.fx!.authorize();
        expect(await c.create(old.name, '09121234567', item: old), isNull);
        expect(
          await c.create(
            old.name,
            '09121234567',
            kind: 'ORGANIZATION',
            item: old,
          ),
          isNull,
        );
        expect(server.writes, isEmpty);
        final address = {
          'addressId': secondId,
          'title': 'دفتر',
          'fullAddress': 'آدرس دفتر',
          'countryCode': 'IR',
          'isDefault': true,
          'postalCode': '۱۲۳۴۵۶۷۸۹۰',
          'latitude': 35.7,
          'longitude': 51.4,
        };
        expect(
          await c.create(
            old.name,
            '09121234567',
            kind: 'PERSON',
            details: {'email': 'invalid'},
          ),
          isNull,
        );
        expect(
          await c.create(
            old.name,
            '09121234567',
            kind: 'PERSON',
            details: {
              'addresses': [
                {...address, 'postalCode': '123'},
              ],
            },
          ),
          isNull,
        );
        expect(server.writes, isEmpty);
        server.lost = true;
        expect(
          await c.create(
            old.name,
            '۰۹۱۲۱۲۳۴۵۶۷',
            kind: 'ORGANIZATION',
            item: old,
            details: {
              'legalName': 'شرکت نمونه',
              'email': 'info@example.com',
              'addresses': [address],
            },
          ),
          isNull,
        );
        expect(c.pending.value!.updating, isTrue);
        final resumed = SuppliersController(appId: app);
        addTearDown(resumed.onClose);
        await resumed.load();
        final edited = (await resumed.create('', ''))!;
        expect(edited.revision, 2);
        expect(edited.kind, 'ORGANIZATION');
        expect(edited.profile['legalName'], 'شرکت نمونه');
        expect(
          (edited.profile['addresses'] as List).single['postalCode'],
          '1234567890',
        );
        expect(server.writes[0].body, server.writes[1].body);
        expect(
          server.writes[0].headers['idempotency-key'],
          server.writes[1].headers['idempotency-key'],
        );
        expect(
          await resumed.create(
            old.name,
            '09121234567',
            kind: 'PERSON',
            item: old,
          ),
          isNull,
        );
        expect(resumed.commandError.value, contains('نسخه جدید'));
        expect(resumed.pending.value, isNull);
        final archived = await resumed.create(
          edited.name,
          edited.phone!,
          kind: edited.kind,
          item: edited,
          status: 'ARCHIVED',
          details: edited.profile,
        );
        expect(archived!.status, 'ARCHIVED');
        expect(resumed.items.where((r) => r.id == edited.id), isEmpty);
        resumed.status.value = 'آرشیو';
        await resumed.load();
        expect(resumed.items.single.id, archived.id);
        final active = await resumed.create(
          archived.name,
          archived.phone!,
          kind: archived.kind,
          item: archived,
          status: 'ACTIVE',
          details: archived.profile,
        );
        expect(active!.status, 'ACTIVE');
        expect(resumed.items, isEmpty);
        // An old persisted command must keep its old endpoint and exact body/key.
        final legacy = SupplierCommand(name: 'قدیمی', phone: '09121234567');
        final restored = SupplierCommand.fromJson({
          'key': legacy.key,
          'body': legacy.body,
        });
        expect(restored.version, 1);
        final result = await resumed.fx!.send(restored);
        expect(result.phone, '09121234567');
        expect(server.writes.last.url.path, endsWith('/accounting/suppliers'));
        expect(server.writes.last.body, jsonEncode(legacy.body));
      },
    );

    testWidgets(
      '$app native supplier form displays failure and confirmed success Alerts',
      (tester) async {
        final server = SupplierServer(app);
        await server.prepare();
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ToastificationWrapper(
            child: DefaultAssetBundle(
              bundle: SupplierAssets(root),
              child: GetMaterialApp(
                onGenerateRoute: navigation.MikRouter(
                  sharedRoutes: SharedRoutes.namedPages,
                ).generateRoute,
                theme: ThemeData(fontFamily: 'ravi'),
                home: SuppliersScreen(appId: app),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('وضعیت مالی: نامشخص'), findsNWidgets(2));
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpAndSettle();
        await tester.tap(find.text('تامین‌کننده جدید'));
        await tester.pumpAndSettle();
        expect(find.byType(Input), findsNWidgets(2));
        expect(find.byType(BTN), findsNWidgets(3));
        await tester.tap(find.text('افزودن'));
        await tester.pumpAndSettle();
        expect(server.writes, isEmpty);
        expect(
          find.text('نام تامین‌کننده الزامی و حداکثر ۲۰۰ حرف است.'),
          findsNWidgets(2),
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('supplier-name')),
            matching: find.byType(TextField),
          ),
          'تامین تازه',
        );
        await tester.tap(find.text('افزودن'));
        await tester.pumpAndSettle();
        expect(server.writes, isEmpty);
        expect(
          find.text('شماره موبایل معتبر با ۰۹ یا +۹۸ وارد کنید.'),
          findsNWidgets(2),
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpAndSettle();
        expect(find.text('نوع تامین‌کننده را انتخاب کنید.'), findsNothing);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('supplier-phone')),
            matching: find.byType(TextField),
          ),
          '09121234567',
        );
        await tester.tap(find.text('افزودن'));
        await tester.pumpAndSettle();
        expect(jsonDecode(server.writes.last.body)['kind'], 'PERSON');
        expect(find.text('تامین‌کننده با موفقیت ثبت شد.'), findsOneWidget);
        expect(find.text('تامین تازه'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey(createdId)));
        await tester.pumpAndSettle();
        expect(find.text('مانده حساب: نامشخص'), findsOneWidget);
        expect(
          server.requests.last.url.path,
          endsWith('/suppliers/$createdId'),
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('ویرایش'));
        await tester.pumpAndSettle();
        expect(find.text('ویرایش تامین‌کننده'), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('supplier-name')),
            matching: find.byType(TextField),
          ),
          'نام ویرایش شده',
        );
        await tester.tap(find.text('ویرایش'));
        await tester.pumpAndSettle();
        expect(
          find.text('اطلاعات تامین‌کننده با موفقیت ویرایش شد.'),
          findsOneWidget,
        );
        expect(find.text('نام ویرایش شده'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
