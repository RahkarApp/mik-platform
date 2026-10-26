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
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/crm.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/crm.dart';
import 'package:mik_pages/customers/crm/remote_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'customers_test.dart' show customer, customerId;

const interactionId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const followupId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

class CrmServer {
  final String app;
  CrmServer(this.app);
  final permissions = <String>{
    'ucrm.customer.read',
    'ucrm.customer.read.all',
    'ucrm.interaction.read',
    'ucrm.interaction.create',
    'ucrm.interaction.update',
    'ucrm.followup.read',
    'ucrm.followup.create',
    'ucrm.followup.update',
  };
  final interactions = <Map<String, dynamic>>[],
      followups = <Map<String, dynamic>>[];
  final writes = <http.Request>[];
  final receipts = <String, Map<String, dynamic>>{};
  bool lost = false, wrongBusiness = false;
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
        'items': [fixtureResult()['branch']],
        'nextCursor': null,
      });
    }
    expect(request.headers['x-app-id'], app);
    expect(request.headers['x-branch-id'], branch);
    if (path.endsWith('/customers')) {
      expect(request.url.queryParameters['status'], 'ALL');
      return jsonResponse({
        'businessId': 12345678,
        'items': [customer()],
        'nextCursor': null,
      });
    }
    final type = path.contains('customer-interactions')
        ? CrmKind.interaction
        : CrmKind.followup;
    final rows = type == CrmKind.interaction ? interactions : followups;
    expect(path, startsWith('/v1/businesses/12345678/${type.path}'));
    Map<String, dynamic> reading(Map<String, dynamic> row) => {
      ...row,
      if (type == CrmKind.followup)
        'overdue':
            row['status'] == 'OPEN' &&
            DateTime.parse(row['dueAt'] as String).isBefore(DateTime.now()),
    };
    if (request.method == 'GET') {
      if (path.endsWith(type.path)) {
        final query = request.url.queryParameters;
        if (type == CrmKind.interaction) {
          expect(query['customerId'], customerId);
        }
        final visible = rows.where(
          (row) =>
              (query['customerId'] == null ||
                  row['customerId'] == query['customerId']) &&
              (query['status'] == null || row['status'] == query['status']),
        );
        return jsonResponse({
          'businessId': wrongBusiness ? 87654321 : 12345678,
          'items': visible.map(reading).toList(),
          'nextCursor': null,
        });
      }
      return jsonResponse({
        'businessId': 12345678,
        'item': reading(
          rows.singleWhere(
            (r) => r[type.idField] == request.url.pathSegments.last,
          ),
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
    final before = update
        ? rows.singleWhere(
            (r) => r[type.idField] == request.url.pathSegments.last,
          )
        : null;
    expect(body.containsKey(type.idField), isFalse);
    if (before != null && before['revision'] != body['expectedRevision']) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    if (before != null &&
        type == CrmKind.followup &&
        before['status'] != 'OPEN' &&
        body['status'] != null &&
        body['status'] != 'OPEN' &&
        body['status'] != before['status']) {
      return jsonResponse({
        'error': {'code': 'INVALID_STATE'},
      }, 409);
    }
    final row = <String, dynamic>{
      ...?before,
      ...body,
      type.idField:
          before?[type.idField] ??
          (type == CrmKind.interaction ? interactionId : followupId),
      'businessId': 12345678,
      'customerId': customerId,
      'createdBy': {'identityId': identity},
      'revision': before == null ? 1 : (before['revision'] as int) + 1,
      'status':
          body['status'] ??
          before?['status'] ??
          (type == CrmKind.interaction ? 'ACTIVE' : 'OPEN'),
      if (type == CrmKind.followup)
        'responsibleMembershipId':
            body['responsibleMembershipId'] ??
            before?['responsibleMembershipId'] ??
            membership,
    }..remove('expectedRevision');
    if (before != null) expect(body['reason'], isNotEmpty);
    if (before == null) {
      rows.add(row);
    } else {
      rows[rows.indexOf(before)] = row;
    }
    final result = {'businessId': 12345678, 'item': row, 'replayed': false};
    receipts[key] = result;
    if (lost) {
      lost = false;
      throw TimeoutException('reply lost');
    }
    return jsonResponse(result, update ? 200 : 201);
  }

  Future<CrmFX> prepare() async {
    final context = pimFixture(MockClient(respond), appId: app).context;
    await context.selectBranch((await context.branches()).single);
    return CrmFX.forContext(context);
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
      '$app CRM exact retry, ownership, statuses, revision and tenant checks',
      () async {
        final server = CrmServer(app);
        final fx = await server.prepare();
        await fx.authorize();
        expect((await fx.customerList()).single.id, customerId);
        final command = CrmCommand(CrmKind.interaction, customerId, {
          'customerId': customerId,
          'kind': 'CALL',
          'body': 'تماس با مشتری',
          'occurredAt': '2026-01-01T10:00:00.000Z',
        });
        server.lost = true;
        await expectLater(fx.send(command), throwsA(isA<TimeoutException>()));
        final restored = await fx.restore();
        expect(restored!.key, command.key);
        final interaction = await fx.send(restored);
        expect(server.interactions.length, 1);
        expect(server.writes[0].body, server.writes[1].body);
        expect(
          server.writes[0].headers['idempotency-key'],
          server.writes[1].headers['idempotency-key'],
        );
        expect(fx.canEdit(interaction), isTrue);
        final other = CrmEntry({
          ...interaction.data,
          'createdBy': {'identityId': followupId},
        }, CrmKind.interaction);
        expect(fx.canEdit(other), isFalse);
        await fx.send(
          CrmCommand(CrmKind.interaction, customerId, {
            'body': 'اصلاح ارتباط',
            'status': 'ARCHIVED',
            'reason': 'اصلاح اطلاعات',
            'expectedRevision': 1,
          }, id: interaction.id),
        );
        expect(
          await fx.list(
            CrmKind.interaction,
            customerId: customerId,
            status: 'ACTIVE',
          ),
          isEmpty,
        );
        expect(
          (await fx.list(
            CrmKind.interaction,
            customerId: customerId,
            status: 'ARCHIVED',
          )).single.status,
          'ARCHIVED',
        );
        await expectLater(
          fx.send(
            CrmCommand(CrmKind.interaction, customerId, {
              'body': 'نسخه قدیمی',
              'reason': 'اصلاح',
              'expectedRevision': 1,
            }, id: interaction.id),
          ),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'REVISION_CONFLICT'),
          ),
        );
        final followup = await fx.send(
          CrmCommand(CrmKind.followup, customerId, {
            'customerId': customerId,
            'title': 'تماس مجدد',
            'dueAt': '2026-01-01T12:00:00.000Z',
          }),
        );
        expect(followup.data.containsKey('overdue'), isFalse);
        expect(
          (await fx.list(
            CrmKind.followup,
            status: 'OPEN',
          )).single.data['overdue'],
          isTrue,
        );
        final done = await fx.send(
          CrmCommand(CrmKind.followup, customerId, {
            'status': 'DONE',
            'reason': 'انجام شد',
            'expectedRevision': 1,
          }, id: followup.id),
        );
        await expectLater(
          fx.send(
            CrmCommand(CrmKind.followup, customerId, {
              'status': 'CANCELLED',
              'reason': 'تغییر نتیجه',
              'expectedRevision': done.revision,
            }, id: done.id),
          ),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'INVALID_STATE'),
          ),
        );
        server.wrongBusiness = true;
        await expectLater(fx.list(CrmKind.followup), throwsFormatException);
        server.permissions.remove('ucrm.interaction.create');
        final count = server.writes.length;
        await expectLater(
          fx.send(command),
          throwsA(isA<AuthError>().having((e) => e.code, 'code', 'FORBIDDEN')),
        );
        expect(server.writes.length, count);
      },
    );

    testWidgets(
      '$app native CRM interaction and followup forms, alerts and edit',
      (tester) async {
        final server = CrmServer(app);
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
              home: CustomerCrmScreen(appId: app, customerId: customerId),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('اطلاعات با موفقیت ثبت شد.'), findsNothing);
        await tester.tap(find.text('ارتباط جدید'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ثبت'));
        await tester.pumpAndSettle();
        expect(server.writes, isEmpty);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('crm-body')),
            matching: find.byType(TextField),
          ),
          'تماس با مشتری انجام شد',
        );
        await tester.tap(find.text('ثبت'));
        await tester.pumpAndSettle();
        expect(server.interactions.single['kind'], 'CALL');
        expect(find.text('اطلاعات با موفقیت ثبت شد.'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byKey(const ValueKey(interactionId)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ویرایش'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('crm-reason')),
            matching: find.byType(TextField),
          ),
          'ثبت نتیجه تماس',
        );
        await tester.tap(find.text('ثبت'));
        await tester.pumpAndSettle();
        expect(server.interactions.single['revision'], 2);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('پیگیری‌ها'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('پیگیری جدید'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('crm-title')),
            matching: find.byType(TextField),
          ),
          'تماس مجدد',
        );
        tester.widget<DateInput>(find.byType(DateInput)).controller.text =
            '1405/10/01 10:00';
        await tester.tap(find.text('ثبت'));
        await tester.pumpAndSettle();
        expect(server.followups.single['responsibleMembershipId'], membership);
        expect(server.followups.single['status'], 'OPEN');
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
