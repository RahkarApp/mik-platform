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
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/invoice_read.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/invoice_payment.dart';
import 'package:mik_pages/invoice/payment_screen.dart';
import 'package:mik_pages/bill/party_payment.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:toastification/toastification.dart';
import 'package:mik_variables/variable.dart' as shared;

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'invoice_read_test.dart'
    show InvoiceReadServer, invoiceOne, invoiceTwo, partyId;

const fundId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const bankId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const terminalId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const paymentId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const sourceId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const allocationId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';

class PaymentServer {
  final String app, type;
  PaymentServer(this.app, {this.type = 'SALE'});
  late final base = InvoiceReadServer(app);
  final requests = <http.Request>[];
  final receipts = <String, Map<String, dynamic>>{};
  final paymentRows = <Map<String, dynamic>>[],
      sourceRows = <Map<String, dynamic>>[];
  bool lose = false,
      allowed = true,
      wrongParty = false,
      insufficient = false,
      extra = false,
      wrongConfirmation = false;
  int settled = 0;
  String get partyType => type == 'PURCHASE' ? 'SUPPLIER' : 'CUSTOMER';
  String get direction => type == 'PURCHASE' ? 'OUT' : 'IN';
  List<http.Request> get writes =>
      requests.where((r) => r.method == 'POST').toList();
  Map<String, dynamic> raw({bool addition = false}) {
    final before = base.detail(type);
    final rootSettled = extra ? 100 : settled;
    final open = extra ? 100 - settled : 100 - settled;
    final totals = {...(before['view'] as Map)['totals'] as Map};
    return {
      ...before,
      'invoiceId': addition ? invoiceTwo : invoiceOne,
      'rootInvoiceId': invoiceOne,
      'partyId': partyId,
      'partyType': partyType,
      'number': addition ? '000002' : '000001',
      'totals': totals,
      'settledAmount': addition ? settled : rootSettled,
      'partySnapshot': {
        ...(before['partySnapshot'] as Map),
        'isDefault': false,
      },
      'view': {
        ...(before['view'] as Map),
        'totals': {...totals, 'total': extra && !addition ? 200 : 100},
        'openAmount': open,
        'settledAmount': extra && !addition ? 100 + settled : settled,
        'paymentStatus': open == 0
            ? 'PAID'
            : settled == 0
            ? 'UNPAID'
            : 'PARTIALLY_PAID',
      },
    };
  }

  Future<BusinessContext> prepare() async {
    final context = pimFixture(MockClient(respond), appId: app).context;
    await context.selectBranch((await context.branches()).single);
    requests.clear();
    return context;
  }

  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    expect(request.headers['x-app-id'], app);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final business = request.url.queryParameters['scopeType'] == 'BUSINESS';
      return jsonResponse({
        ...fixtureAuthorization(
          business
              ? [
                  'accounting.payment.read',
                  'accounting.account.read',
                  'accounting.bank.use',
                  if (allowed) 'accounting.payment.create',
                ]
              : [
                  'accounting.sale.read',
                  'accounting.purchase.read',
                  'accounting.presale.read',
                  'accounting.payment.allocate',
                  'accounting.treasury.use',
                ],
        ),
        'scopeType': business ? 'BUSINESS' : 'BRANCH',
        'scopeId': business ? '12345678' : branch,
      });
    }
    if (path.endsWith('/branches')) {
      return jsonResponse({
        'items': [fixtureResult()['branch']],
        'nextCursor': null,
      });
    }
    expect(request.headers['x-branch-id'], branch);
    if (request.method == 'GET') {
      if (path.contains('/invoices/')) {
        return jsonResponse({
          'businessId': 12345678,
          'invoice': raw(addition: path.endsWith(invoiceTwo)),
          'relatedDocuments': extra && !path.endsWith(invoiceTwo)
              ? [
                  {'invoiceId': invoiceTwo, 'type': type, 'status': 'ISSUED'},
                ]
              : [],
        });
      }
      if (path.endsWith('/treasury/options')) {
        return jsonResponse({
          'businessId': 12345678,
          'items': request.url.queryParameters['kind'] == 'terminal'
              ? [
                  {
                    'terminalId': terminalId,
                    'fundId': bankId,
                    'branchId': branch,
                    'name': 'کارت‌خوان شعبه',
                  },
                ]
              : [
                  {
                    'fundId': fundId,
                    'kind': 'CASH',
                    'branchId': branch,
                    'name': 'صندوق شعبه',
                  },
                  {'fundId': bankId, 'kind': 'BANK', 'name': 'حساب بانکی'},
                ],
          'nextCursor': null,
        });
      }
      expect(request.url.queryParameters['partyId'], partyId);
      expect(request.url.queryParameters['partyType'], partyType);
      if (path.endsWith('/payments')) {
        return jsonResponse({
          'businessId': 12345678,
          'items': paymentRows,
          'nextCursor': null,
        });
      }
      if (path.endsWith('/sources')) {
        return jsonResponse({
          'businessId': 12345678,
          'items': sourceRows
              .map((r) => {...r, if (wrongParty) 'partyId': invoiceTwo})
              .toList(),
          'nextCursor': null,
        });
      }
    }
    expect(request.method, 'POST');
    final key = request.headers['idempotency-key']!;
    if (receipts.containsKey(key)) {
      final reply = receipts[key]!;
      if (wrongConfirmation && reply.containsKey('payment')) {
        return jsonResponse({
          ...reply,
          'payment': {
            ...(reply['payment'] as Map),
            'routing': {'fundId': bankId},
          },
        });
      }
      return jsonResponse(reply);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    late Map<String, dynamic> result;
    if (path.endsWith('/v2/payments')) {
      expect(body.keys.toSet(), {'partyId', 'partyType', 'payment'});
      final p = body['payment'] as Map<String, dynamic>;
      expect(p['confirmed'], true);
      expect(p['direction'], direction);
      if (insufficient) {
        return jsonResponse({
          'error': {'code': 'INSUFFICIENT_FUNDS'},
        }, 409);
      }
      final stored = <String, dynamic>{...p}..remove('confirmed');
      final row = <String, dynamic>{
        'businessId': 12345678,
        'branchId': branch,
        'partyId': partyId,
        'partyType': partyType,
        'paymentId': paymentId,
        'status': 'CONFIRMED',
        'purpose': 'SETTLEMENT',
        'financialVersion': 2,
        'revision': 1,
        ...stored,
      };
      paymentRows.add(row);
      sourceRows.add({
        'businessId': 12345678,
        'sourceId': sourceId,
        'partyId': partyId,
        'partyType': partyType,
        'kind': 'PAYMENT',
        'referenceId': paymentId,
        'status': 'ACTIVE',
        'amount': p['amount'],
        'usedAmount': 0,
      });
      result = {'businessId': 12345678, 'payment': row};
    } else {
      expect(path.endsWith('/settlements'), true);
      expect(body.keys.toSet(), {'sourceId', 'invoiceId', 'amount'});
      final source = sourceRows.single;
      final amount = body['amount'] as int;
      if (amount > (source['amount'] as int) - (source['usedAmount'] as int) ||
          amount > 100 - settled) {
        return jsonResponse({
          'error': {'code': 'SETTLEMENT_EXCEEDED'},
        }, 409);
      }
      source['usedAmount'] = (source['usedAmount'] as int) + amount;
      settled += amount;
      result = {
        'businessId': 12345678,
        'allocation': {
          'allocationId': allocationId,
          'businessId': 12345678,
          'partyId': partyId,
          'partyType': partyType,
          'sourceId': sourceId,
          'invoiceId': body['invoiceId'],
          'amount': amount,
          'reversedAmount': 0,
        },
        'invoice': raw(addition: body['invoiceId'] == invoiceTwo),
      };
    }
    final saved = jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
    receipts[key] = saved;
    if (lose) {
      lose = false;
      throw TimeoutException('reply lost');
    }
    if (wrongConfirmation && result.containsKey('payment')) {
      return jsonResponse({
        ...result,
        'payment': {
          ...(result['payment'] as Map),
          'routing': {'fundId': bankId},
        },
      });
    }
    return jsonResponse(result);
  }

  RemoteInvoiceSummary get summary =>
      RemoteInvoiceSummary.fromJson(base.summary(type));
  InvoicePaymentCommand command(int value) => InvoicePaymentCommand('PAYMENT', {
    'partyId': partyId,
    'partyType': partyType,
    'payment': {
      'amount': value,
      'direction': direction,
      'method': 'CASH',
      'confirmed': true,
      'routing': {'fundId': fundId},
    },
  });
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
      '$app direct party payment uses no invoice and resumes exact command',
      () async {
        for (final type in ['SALE', 'PURCHASE']) {
          final server = PaymentServer(app, type: type)..lose = true;
          final context = await server.prepare();
          final fx = InvoicePaymentFX.forParty(
            context,
            server.partyType,
            partyId,
          );
          await fx.authorize();
          expect((await fx.targets('CASH')).single.id, fundId);
          expect(
            (await fx.targets('CARD')).single.id,
            type == 'SALE' ? terminalId : bankId,
          );
          final command = server.command(100);
          await expectLater(fx.send(command), throwsA(isA<TimeoutException>()));
          final resumed = InvoicePaymentFX.forParty(
            context,
            server.partyType,
            partyId,
          );
          final pending = await resumed.restore();
          expect(pending!.key, command.key);
          await expectLater(
            resumed.send(server.command(50)),
            throwsA(isA<AuthError>()),
          );
          server.wrongConfirmation = true;
          await expectLater(resumed.send(pending), throwsFormatException);
          expect(resumed.pending, isNotNull);
          server.wrongConfirmation = false;
          await resumed.send(pending);
          expect(resumed.pending, isNull);
          expect(server.paymentRows, hasLength(1));
          expect(server.writes.map((r) => r.body).toSet(), hasLength(1));
          expect(
            server.writes.map((r) => r.headers['idempotency-key']).toSet(),
            {command.key},
          );
          expect(
            server.requests.where((r) => r.url.path.contains('/invoices')),
            isEmpty,
          );
          await expectLater(
            resumed.send(InvoicePaymentCommand('ALLOCATE', {})),
            throwsFormatException,
          );
          server.allowed = false;
          final count = server.writes.length;
          await expectLater(
            resumed.send(server.command(100)),
            throwsA(isA<AuthError>()),
          );
          expect(server.writes.length, count);
        }
      },
    );

    testWidgets(
      '$app direct native form confirms actual funds before posting',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = PaymentServer(
          app,
          type: app == 'mik' ? 'SALE' : 'PURCHASE',
        );
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('open'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PartyPaymentScreen(
                          appId: app,
                          partyType: server.partyType,
                          partyId: partyId,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final submit = find.widgetWithText(
          BTN,
          app == 'mik' ? 'ثبت دریافت وجه' : 'ثبت پرداخت وجه',
        );
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(server.writes, isEmpty);
        expect(
          find.text('مبلغ مثبت و حساب مبدأ یا مقصد لازم است.'),
          findsOneWidget,
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.ensureVisible(find.text('صندوق شعبه'));
        await tester.tap(find.text('صندوق شعبه'));
        await tester.pumpAndSettle();
        final input = find.descendant(
          of: find.byKey(const ValueKey('party-payment-amount')),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(input);
        await tester.enterText(input, '۱۰۰');
        expect(
          find.text('آیا جابه‌جایی وجه واقعاً انجام شده است؟'),
          findsNothing,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(server.paymentRows, hasLength(1));
        expect(server.paymentRows.single['direction'], server.direction);
        expect(find.text('open'), findsOneWidget);
        expect(
          server.requests.where((r) => r.url.path.contains('/invoices')),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
      },
    );

    test(
      '$app received funds survive lost reply and allocate to actual family debit',
      () async {
        final server = PaymentServer(app)..extra = true;
        final context = await server.prepare();
        final fx = InvoicePaymentFX(context, server.summary);
        await fx.authorize();
        final invoice = await fx.invoiceDetails();
        expect(invoice.detail.summary.openAmount, 100);
        expect(invoice.documents.first.remaining, 0);
        expect(invoice.documents.last.id, invoiceTwo);
        expect((await fx.targets('CARD')).single.id, terminalId);
        expect((await fx.targets('BANK_TRANSFER')).single.id, bankId);
        server.lose = true;
        final command = server.command(100);
        await expectLater(fx.send(command), throwsA(isA<TimeoutException>()));
        final resumed = InvoicePaymentFX(context, server.summary);
        final pending = await resumed.restore();
        await resumed.send(pending!);
        expect(server.paymentRows, hasLength(1));
        expect(server.writes[0].body, server.writes[1].body);
        expect(
          server.writes[0].headers['idempotency-key'],
          server.writes[1].headers['idempotency-key'],
        );
        expect((await resumed.invoiceDetails()).detail.summary.openAmount, 100);
        final sources = await resumed.sources();
        expect(sources.single.available, 100);
        await resumed.send(
          InvoicePaymentCommand('ALLOCATE', {
            'sourceId': sourceId,
            'invoiceId': invoiceTwo,
            'amount': 100,
          }),
        );
        expect((await resumed.invoiceDetails()).detail.summary.openAmount, 0);
        expect(await resumed.sources(), isEmpty);
        expect(resumed.pending, isNull);
      },
    );
    test(
      '$app outgoing bank routing, malformed replies, insufficient funds and permissions',
      () async {
        final server = PaymentServer(app, type: 'PURCHASE');
        final context = await server.prepare();
        final fx = InvoicePaymentFX(context, server.summary);
        await fx.authorize();
        expect((await fx.targets('CARD')).single.id, bankId);
        server.insufficient = true;
        await expectLater(
          fx.send(server.command(100)),
          throwsA(
            isA<AuthError>().having(
              (e) => e.code,
              'code',
              'INSUFFICIENT_FUNDS',
            ),
          ),
        );
        expect(fx.pending, isNull);
        server.insufficient = false;
        server.wrongConfirmation = true;
        await expectLater(fx.send(server.command(100)), throwsFormatException);
        expect(fx.pending, isNotNull);
        final retry = fx.pending!;
        server.wrongConfirmation = false;
        await fx.send(retry);
        expect(fx.pending, isNull);
        expect(server.paymentRows, hasLength(1));
        server.wrongParty = true;
        await expectLater(fx.sources(), throwsFormatException);
        server.allowed = false;
        await fx.authorize();
        final count = server.writes.length;
        await expectLater(
          fx.send(server.command(100)),
          throwsA(isA<AuthError>()),
        );
        expect(server.writes.length, count);
      },
    );
    testWidgets(
      '$app native invoice payment automatically confirms money movement and shows actual settlement',
      (tester) async {
        final previousCurrency = shared.currencyType;
        shared.currencyType = 0;
        addTearDown(() => shared.currencyType = previousCurrency);
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = PaymentServer(
          app,
          type: app == 'mik' ? 'SALE' : 'PURCHASE',
        );
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: InvoicePaymentScreen(appId: app, invoice: server.summary),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('ماندهٔ فاکتور: 100 تومان'), findsOneWidget);
        final pay = find.text(
          app == 'mik' ? 'ثبت دریافت وجه' : 'ثبت پرداخت وجه',
        );
        await tester.ensureVisible(pay);
        await tester.tap(pay);
        await tester.pumpAndSettle();
        expect(server.writes, isEmpty);
        expect(
          find.text('مبلغ مثبت و حساب مقصد یا مبدأ لازم است.'),
          findsOneWidget,
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.ensureVisible(find.text('صندوق شعبه'));
        await tester.tap(find.text('صندوق شعبه'));
        await tester.pumpAndSettle();
        final input = find.descendant(
          of: find.byKey(const ValueKey('payment-amount')),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(input);
        await tester.enterText(input, '۱۰۰');
        expect(
          find.text('آیا جابه‌جایی وجه واقعاً انجام شده است؟'),
          findsNothing,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(pay);
        await tester.tap(pay);
        await tester.pumpAndSettle();
        expect(server.paymentRows, hasLength(1));
        expect(server.settled, 0);
        expect(
          find.text(
            'وجه با موفقیت ثبت شد؛ وضعیت تخصیص و ماندهٔ فاکتور را بررسی کنید.',
          ),
          findsOneWidget,
        );
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        final credit = find.textContaining('وجه ثبت‌شده 1:');
        await tester.ensureVisible(credit);
        await tester.tap(credit);
        await tester.pumpAndSettle();
        final doc = find.text('000001: 100 تومان');
        await tester.ensureVisible(doc);
        await tester.tap(doc);
        await tester.pumpAndSettle();
        final allocation = find.descendant(
          of: find.byKey(const ValueKey('allocation-amount')),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(allocation);
        await tester.enterText(allocation, '100');
        await tester.ensureVisible(find.text('تخصیص اعتبار'));
        await tester.tap(find.text('تخصیص اعتبار'));
        await tester.pumpAndSettle();
        expect(server.settled, 100);
        expect(
          find.text('اعتبار با موفقیت به سند فاکتور تخصیص یافت.'),
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
