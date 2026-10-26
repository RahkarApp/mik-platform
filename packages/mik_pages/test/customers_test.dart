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
import 'package:mik_data/source/remote/models/customer.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/customers.dart';
import 'package:mik_pages/customers/customer_controller.dart';
import 'package:mik_pages/customers/customer_form.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const customerId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const otherCustomer = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const addressId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
Map<String, dynamic> customer({String id = customerId, String name = 'رضا'}) =>
    {
      'businessId': 12345678,
      'customerId': id,
      'name': name,
      'phone': '+989000000011',
      'kind': 'PERSON',
      'status': 'ACTIVE',
      'revision': 3,
      'isDefault': false,
      'createdBy': {'identityId': identity},
      'assignedMembershipIds': [],
      'addresses': [],
      'groupIds': [],
      'tagIds': [],
    };

class CustomersServer {
  final String app;
  CustomersServer(this.app);
  final requests = <http.Request>[];
  final permissions = [
    'ucrm.customer.read',
    'ucrm.customer.create',
    'ucrm.customer.update',
  ];
  Map<String, dynamic> row = customer();
  final receipts = <String, Map<String, dynamic>>{};
  bool lostResponse = false, conflict = false;
  Completer<http.Response>? listReply;
  List<http.Request> get mutations =>
      requests.where((r) => r.method != 'GET').toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
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
    if (path.endsWith('/customers') && request.method == 'GET') {
      if (listReply != null) return listReply!.future;
      final after = request.url.queryParameters['after'];
      return jsonResponse({
        'businessId': 12345678,
        'items': [
          after == null ? row : customer(id: otherCustomer, name: 'مریم'),
        ],
        'nextCursor': after == null ? customerId : null,
      });
    }
    if (path.endsWith('/$customerId') && request.method == 'GET') {
      return jsonResponse({'businessId': 12345678, 'customer': row});
    }
    final key = request.headers['idempotency-key']!;
    if (receipts.containsKey(key)) return jsonResponse(receipts[key]!);
    if (conflict) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    final body = Map<String, dynamic>.from(jsonDecode(request.body));
    row = {...row, ...body, 'revision': (row['revision'] as int) + 1}
      ..remove('expectedRevision');
    final reply = {'businessId': 12345678, 'customer': row, 'replayed': false};
    receipts[key] = reply;
    if (lostResponse) {
      lostResponse = false;
      throw TimeoutException('lost response');
    }
    return jsonResponse(reply, request.method == 'POST' ? 201 : 200);
  }

  Future<CustomersFX> prepare() async {
    final context = pimFixture(MockClient(respond), appId: app).context;
    await context.selectBranch((await context.branches()).single);
    final fx = CustomersFX(context: context);
    await fx.authorize();
    requests.clear();
    return fx;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  setUp(resetOnboardingStorage);
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app scoped cursor list/search ignores a late reply after branch changes',
      () async {
        final server = CustomersServer(app);
        await server.prepare();
        final c = RemoteCustomersController(appId: app);
        addTearDown(c.onClose);
        await c.load();
        await c.load(more: true);
        expect(c.items.map((p) => p.id), [customerId, otherCustomer]);
        expect(c.error.value, isNull);
        expect(
          server.requests
              .where((r) => r.url.path.endsWith('/customers'))
              .last
              .url
              .queryParameters['after'],
          customerId,
        );
        c.query = 'رض';
        await c.load();
        final request = server.requests.last;
        expect(request.url.queryParameters['q'], 'رض');
        expect(request.url.queryParameters['status'], 'ACTIVE');
        expect(request.headers['x-branch-id'], branch);
        expect(request.headers['x-app-id'], app);
        c.query = 'ر';
        final count = server.requests.length;
        await c.load();
        expect(c.searchHint.value, isNotNull);
        expect(server.requests.length, count);
        c.query = '';
        server.listReply = Completer<http.Response>();
        final listCount = server.requests
            .where((r) => r.url.path.endsWith('/customers'))
            .length;
        final loading = c.load();
        while (server.requests
                .where((r) => r.url.path.endsWith('/customers'))
                .length ==
            listCount) {
          await Future<void>.delayed(Duration.zero);
        }
        // A branch switch invalidates even a successful HTTP reply.
        BusinessContext.forApp(app)!.clearAccess();
        server.listReply!.complete(
          jsonResponse({
            'businessId': 12345678,
            'items': [server.row],
            'nextCursor': null,
          }),
        );
        await loading;
        expect(c.items, isEmpty);
        expect(c.error.value, isNotNull);
      },
    );
    test(
      '$app validates create and resumes exact persisted key/body after lost response',
      () async {
        final server = CustomersServer(app);
        final fx = await server.prepare();
        final c = CustomerEditorController(fx: fx);
        addTearDown(c.onClose);
        await c.load();
        c.fields['name']!.text = 'مشتری جدید';
        c.fields['phone']!.text = '۱۲۳';
        expect(await c.save(), isNull);
        expect(server.mutations, isEmpty);
        c.fields['phone']!.text = '۰۹۰۰۰۰۰۰۰۱۱';
        server.lostResponse = true;
        expect(await c.save(), isNull);
        expect(fx.pending, isNotNull);
        final recovered = CustomersFX(context: fx.context);
        final retry = CustomerEditorController(fx: recovered);
        addTearDown(retry.onClose);
        await retry.load();
        expect(retry.pending.value, isNotNull);
        expect(retry.fields['name']!.text, 'مشتری جدید');
        expect(await retry.save(), isNotNull);
        expect(server.mutations.length, 2);
        expect(
          server.mutations[0].headers['idempotency-key'],
          server.mutations[1].headers['idempotency-key'],
        );
        expect(server.mutations[0].body, server.mutations[1].body);
        expect(
          jsonDecode(server.mutations.first.body)['phone'],
          '+989000000011',
        );
        expect(recovered.pending, isNull);
        expect(await recovered.restore(), isNull);
        expect(server.receipts.length, 1);
      },
    );
    test(
      '$app patch keeps other addresses, blocks default/foreign customer and revision conflict',
      () async {
        final server = CustomersServer(app);
        server.row['addresses'] = [
          {
            'addressId': addressId,
            'title': 'خانه',
            'fullAddress': 'نشانی قبلی',
            'isDefault': true,
            'latitude': 35,
            'longitude': 51,
          },
          {
            'addressId': otherCustomer,
            'title': 'شرکت',
            'fullAddress': 'نشانی دوم',
            'isDefault': false,
          },
        ];
        server.row['birthDate'] = '2000-01-01';
        final fx = await server.prepare();
        expect(
          fx.canEdit(
            RemoteCustomer.fromJson({...server.row, 'isDefault': true}),
          ),
          isFalse,
        );
        expect(
          fx.canEdit(
            RemoteCustomer.fromJson({
              ...server.row,
              'createdBy': {'identityId': otherCustomer},
            }),
          ),
          isFalse,
        );
        expect(
          fx.canEdit(
            RemoteCustomer.fromJson({
              ...server.row,
              'createdBy': {'identityId': otherCustomer},
              'assignedMembershipIds': [membership],
            }),
          ),
          isTrue,
        );
        final c = CustomerEditorController(fx: fx, id: customerId);
        addTearDown(c.onClose);
        await c.load();
        c.fields['fullAddress']!.text = 'نشانی اصلاح‌شده';
        final body = c.body();
        expect(body['expectedRevision'], 3);
        expect(body.containsKey('birthDate'), isFalse);
        expect(
          (body['addresses'] as List)[1],
          (server.row['addresses'] as List)[1],
        );
        expect((body['addresses'] as List)[0]['latitude'], 35);
        server.conflict = true;
        expect(await c.save(), isNull);
        expect(c.conflict.value, isTrue);
        final count = server.mutations.length;
        await c.save();
        expect(server.mutations.length, count);
        server.conflict = false;
        await c.load();
        c.fields['name']!.text = 'رضای جدید';
        expect(await c.save(), isNotNull);
        expect(server.mutations.last.method, 'PATCH');
        expect(
          server.mutations.last.url.path.endsWith('/customers/$customerId'),
          isTrue,
        );
        expect(jsonDecode(server.mutations.last.body)['expectedRevision'], 3);
        server.permissions.remove('ucrm.customer.update');
        await fx.authorize();
        expect(c.canSave, isFalse);
        final beforeDenied = server.mutations.length;
        expect(await c.save(), isNull);
        expect(server.mutations.length, beforeDenied);
      },
    );
    testWidgets('$app form uses native Input/BTN and saves organization data', (
      tester,
    ) async {
      final server = CustomersServer(app);
      final fx = await server.prepare();
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        GetMaterialApp(
          onGenerateRoute: navigation.MikRouter(
            sharedRoutes: SharedRoutes.namedPages,
          ).generateRoute,
          theme: ThemeData(fontFamily: 'ravi'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CustomerFormScreen(fx: fx)),
                ),
                child: const Text('باز کردن'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('باز کردن'));
      await tester.pumpAndSettle();
      expect(find.byType(Input), findsWidgets);
      expect(
        tester.widgetList<BTN>(find.byType(BTN)).any((b) => b.name == 'افزودن'),
        isTrue,
      );
      await tester.tap(find.text('حقوقی'));
      await tester.pumpAndSettle();
      Finder field(String name) => find.descendant(
        of: find.byKey(ValueKey('customer-$name')),
        matching: find.byType(TextField),
      );
      await tester.enterText(field('name'), 'شرکت نمونه');
      await tester.enterText(field('contactName'), 'رابط شرکت');
      await tester.enterText(field('phone'), '09000000011');
      await tester.tap(find.text('افزودن').first);
      await tester.pumpAndSettle();
      expect(server.mutations.length, 1);
      expect(
        jsonDecode(server.mutations.single.body),
        containsPair('kind', 'ORGANIZATION'),
      );
      expect(
        jsonDecode(server.mutations.single.body),
        containsPair('contactName', 'رابط شرکت'),
      );
      expect(find.text('باز کردن'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
