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
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/treasury.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/treasury.dart';
import 'package:mik_pages/treasury/screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const cashId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const bankId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const terminalId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const newFundId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const otherBranch = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

class TreasuryServer {
  final String app;
  TreasuryServer(this.app);
  bool write = true,
      bankAccess = true,
      lose = false,
      wrongScope = false,
      used = false;
  final requests = <http.Request>[];
  final receipts = <String, Map<String, dynamic>>{};
  final funds = <Map<String, dynamic>>[
    {
      'businessId': 12345678,
      'fundId': cashId,
      'branchId': branch,
      'name': 'صندوق شعبه',
      'kind': 'CASH',
      'status': 'ACTIVE',
      'revision': 1,
      'balance': 500,
      'heldAmount': 100,
    },
    {
      'businessId': 12345678,
      'fundId': bankId,
      'name': 'حساب اصلی',
      'kind': 'BANK',
      'status': 'ACTIVE',
      'revision': 1,
      'balance': 0,
      'heldAmount': 0,
    },
  ];
  final terminals = <Map<String, dynamic>>[];
  List<http.Request> get writes =>
      requests.where((r) => r.method == 'POST').toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    expect(request.headers['x-app-id'], app);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final business = request.url.queryParameters['scopeType'] == 'BUSINESS';
      final permissions = business
          ? [
              if (bankAccess) ...[
                'accounting.bank.read',
                'accounting.bank.use',
                if (write) 'accounting.bank.manage',
              ],
            ]
          : [
              'accounting.treasury.read',
              'accounting.terminal.read',
              if (write) ...[
                'accounting.treasury.manage',
                'accounting.terminal.manage',
              ],
            ];
      return jsonResponse({
        ...fixtureAuthorization(permissions),
        'scopeType': business ? 'BUSINESS' : 'BRANCH',
        'scopeId': business ? '12345678' : branch,
      });
    }
    expect(request.headers['x-branch-id'], branch);
    expect(path, startsWith('/v1/businesses/12345678/accounting/treasury/'));
    Map<String, dynamic> decorate(Map<String, dynamic> row) => {
      ...row,
      'availableAmount': (row['balance'] as int) - (row['heldAmount'] as int),
      if (wrongScope) 'branchId': otherBranch,
    };
    if (request.method == 'GET') {
      if (path.endsWith('/funds/$cashId') || path.endsWith('/funds/$bankId')) {
        return jsonResponse({
          'businessId': 12345678,
          'item': decorate(
            funds.firstWhere((r) => path.endsWith(r['fundId'] as String)),
          ),
        });
      }
      if (path.endsWith('/funds')) {
        final kind = request.url.queryParameters['kind'];
        return jsonResponse({
          'businessId': 12345678,
          'items': funds.where((r) => r['kind'] == kind).map(decorate).toList(),
          'nextCursor': null,
        });
      }
      if (path.endsWith('/terminals')) {
        return jsonResponse({
          'businessId': 12345678,
          'items': terminals,
          'nextCursor': null,
        });
      }
    }
    expect(request.method, 'POST');
    final key = request.headers['idempotency-key']!;
    if (receipts.containsKey(key)) return jsonResponse(receipts[key]!);
    final data = jsonDecode(request.body) as Map<String, dynamic>;
    final isTerminal = path.contains('/terminals');
    final update = path.endsWith('/update');
    final rows = isTerminal ? terminals : funds;
    final idKey = isTerminal ? 'terminalId' : 'fundId';
    Map<String, dynamic> row;
    if (update) {
      row = rows.firstWhere((r) => r[idKey] == data[idKey]);
      if (row['revision'] != data['expectedRevision']) {
        return jsonResponse({
          'error': {'code': 'REVISION_CONFLICT'},
        }, 409);
      }
      if (used && data['status'] == 'ARCHIVED') {
        return jsonResponse({
          'error': {'code': 'RECORD_IN_USE'},
        }, 409);
      }
      row.addAll({...data}..remove('expectedRevision'));
      row['revision'] = (row['revision'] as int) + 1;
    } else {
      row = {
        'businessId': 12345678,
        'revision': 1,
        'status': 'ACTIVE',
        idKey: isTerminal ? terminalId : newFundId,
        if (isTerminal || data['kind'] != 'BANK') 'branchId': branch,
        if (!isTerminal) ...{'balance': 0, 'heldAmount': 0, 'openingAmount': 0},
        ...data,
      };
      rows.add(row);
    }
    final result = jsonDecode(
      jsonEncode({
        'businessId': 12345678,
        isTerminal ? 'terminal' : 'fund': row,
        'replayed': false,
      }),
    ) as Map<String, dynamic>;
    receipts[key] = result;
    if (lose) {
      lose = false;
      throw TimeoutException('lost reply');
    }
    return jsonResponse(result);
  }

  BusinessContext activate() =>
      pimFixture(MockClient(respond), appId: app).context;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var dir = Directory.current;
    while (!File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      if (dir.path == dir.parent.path) throw StateError('Workspace not found');
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
    toastification.dismissAll(delayForAnimation: false);
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app treasury scope, actual balances, durable retry and terminal bank link',
      () async {
        final server = TreasuryServer(app);
        final context = server.activate();
        final fx = TreasuryFX(context, branch);
        await fx.authorize();
        final cash = (await fx.funds('CASH')).single;
        expect(cash.balance, 500);
        expect(cash.availableAmount, 400);
        expect((await fx.funds('BANK')).single.branchId, isNull);
        final command = TreasuryCommand('funds', {
          'name': 'صندوق دوم',
          'kind': 'CASH',
        });
        server.lose = true;
        await expectLater(fx.send(command), throwsA(isA<TimeoutException>()));
        final resumed = TreasuryFX(context, branch);
        final pending = await resumed.restore();
        expect(pending!.key, command.key);
        final saved = await resumed.send(pending) as TreasuryFund;
        expect(saved.name, 'صندوق دوم');
        expect(resumed.pending, isNull);
        expect(
          server.writes[0].headers['idempotency-key'],
          server.writes[1].headers['idempotency-key'],
        );
        expect(server.writes[0].body, server.writes[1].body);
        expect(
          server.funds.where((r) => r['name'] == 'صندوق دوم'),
          hasLength(1),
        );
        final terminal = await resumed.send(
          TreasuryCommand('terminals', {
            'name': 'پایانه اول',
            'fundId': bankId,
            'terminalNumber': '123',
          }),
        ) as TreasuryTerminal;
        expect(terminal.fundId, bankId);
        expect((await resumed.terminals()).single.id, terminalId);
        server.wrongScope = true;
        await expectLater(resumed.funds('CASH'), throwsFormatException);
      },
    );
    test(
      '$app treasury revision conflict, in-use archive and permissions',
      () async {
        final server = TreasuryServer(app);
        final fx = TreasuryFX(server.activate(), branch);
        await fx.authorize();
        await expectLater(
          fx.send(
            TreasuryCommand('funds', {
              'fundId': cashId,
              'name': 'نام تازه',
              'expectedRevision': 99,
              'status': 'ACTIVE',
            }),
          ),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'REVISION_CONFLICT'),
          ),
        );
        expect(fx.pending, isNull);
        server.used = true;
        await expectLater(
          fx.send(
            TreasuryCommand('funds', {
              'fundId': cashId,
              'name': 'صندوق شعبه',
              'expectedRevision': 1,
              'status': 'ARCHIVED',
            }),
          ),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'RECORD_IN_USE'),
          ),
        );
        expect(fx.pending, isNull);
        expect(server.funds.first['status'], 'ACTIVE');
        server.write = false;
        await fx.authorize();
        final count = server.writes.length;
        await expectLater(
          fx.send(
            TreasuryCommand('funds', {'name': 'صندوق غیرمجاز', 'kind': 'CASH'}),
          ),
          throwsA(isA<AuthError>()),
        );
        expect(server.writes.length, count);
        server.bankAccess = false;
        await fx.authorize();
        await expectLater(fx.funds('BANK'), throwsA(isA<AuthError>()));
      },
    );
    testWidgets(
      '$app native treasury screen silently reads and confirms create',
      (tester) async {
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = TreasuryServer(app)..activate();
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
        expect(find.text('صندوق شعبه'), findsOneWidget);
        expect(find.text('اطلاعات خزانه با موفقیت ثبت شد.'), findsNothing);
        await tester.tap(find.text('افزودن صندوق'));
        await tester.pumpAndSettle();
        expect(find.byType(Input), findsOneWidget);
        expect(find.byType(BTN), findsWidgets);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('treasury-name')),
            matching: find.byType(TextFormField),
          ),
          'صندوق جدید',
        );
        await tester.tap(find.text('ذخیره'));
        await tester.pumpAndSettle();
        expect(server.writes, hasLength(1));
        expect(jsonDecode(server.writes.single.body), {
          'name': 'صندوق جدید',
          'kind': 'CASH',
        });
        expect(find.text('اطلاعات خزانه با موفقیت ثبت شد.'), findsOneWidget);
        expect(find.text('صندوق جدید'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('کارت‌خوان'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('افزودن کارت‌خوان'));
        await tester.pumpAndSettle();
        expect(find.byType(MiniBTN), findsWidgets);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('treasury-name')),
            matching: find.byType(TextFormField),
          ),
          'کارت‌خوان جدید',
        );
        await tester.tap(find.text('حساب اصلی'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ذخیره'));
        await tester.pumpAndSettle();
        expect(server.terminals.single['fundId'], bankId);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
