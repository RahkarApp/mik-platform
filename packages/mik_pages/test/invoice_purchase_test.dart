import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';
import 'package:mik_pages/invoice/add/components/item/item.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_data/source/remote/models/invoice_amounts.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/invoice/add/purchase_controller.dart';
import 'package:mik_pages/invoice/add/purchase_products.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const cashFund = '55555555-5555-4555-8555-555555555559';
const bankFund = '66666666-6666-4666-8666-666666666669';

const supplierId = '11111111-1111-4111-8111-111111111119';
const operationId = '22222222-2222-4222-8222-222222222229';
const invoiceId = '33333333-3333-4333-8333-333333333339';

class PurchaseServer {
  final String app;
  PurchaseServer(this.app);
  final requests = <http.Request>[];
  bool amountPermissions = false;
  bool paymentAllowed = false, bankAllowed = true, targetsAvailable = true;
  int paid = 0;
  bool allowed = true, receive = true, lost = false, wrongInvoice = false;
  bool linkReceive = true;
  String status = 'PENDING', next = 'SUCCEEDED';
  int revision = 1, total = 0;
  Completer<http.Response>? delayed;
  final receipts = <String, Map<String, dynamic>>{};
  Map<String, Object> get party => {
    'businessId': 12345678,
    'supplierId': supplierId,
    'name': 'تامین نمونه',
    'phone': '09121234567',
    'status': 'ACTIVE',
    'revision': 1,
  };
  Map<String, Object> get operation => {
    'operationId': operationId,
    'command': 'invoice.create.v2',
    'status': status,
    'revision': revision,
    if (status == 'SUCCEEDED') 'result': {'invoiceId': invoiceId},
    if (status == 'FAILED') 'errorCode': 'FORBIDDEN',
  };
  List<http.Request> get writes => requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith('/v2/invoices'))
      .toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final scope = request.url.queryParameters['scopeType'];
      return jsonResponse({
        ...fixtureAuthorization([
          if (allowed) ...[
            'accounting.purchase.create',
            'accounting.purchase.read',
            if (amountPermissions) ...[
              'accounting.purchase.discount.apply',
              'accounting.purchase.surcharge.apply',
            ],
          ],
          if (paymentAllowed) ...[
            'accounting.payment.create',
            'accounting.payment.allocate',
            'accounting.treasury.use',
            'accounting.purchase.payment.pay',
            'accounting.purchase.cheque.pay',
            if (bankAllowed) 'accounting.bank.use',
          ],
          if (receive) 'inventory.stock.receive',
          'business.warehouse.read',
          // Operational receiving does not require management of warehouse links.
          'accounting.supplier.read',
          'pim.product.read',
          'pim.variant.read',
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
    if (path.endsWith('/branches/$branch')) {
      return jsonResponse({
        'item': {...(fixtureResult()['branch'] as Map), 'revision': 2},
      });
    }
    if (path.endsWith('/inventory-access/check')) {
      expect(request.method, 'POST');
      expect(request.headers.containsKey('idempotency-key'), isFalse);
      expect(jsonDecode(request.body), {
        'branchId': branch,
        'warehouseId': warehouse,
        'operation': 'RECEIVE_STOCK',
      });
      if (!receive || !linkReceive) {
        return jsonResponse({
          'error': {'code': 'FORBIDDEN'},
        }, 403);
      }
      return jsonResponse({
        'allowed': true,
        'branchId': branch,
        'warehouseId': warehouse,
        'permissionCode': 'inventory.stock.receive',
      });
    }
    if (path.endsWith('/treasury/options')) {
      expect(request.url.queryParameters['kind'], 'fund');
      return jsonResponse({
        'businessId': 12345678,
        'items': [
          if (targetsAvailable) ...[
            {
              'fundId': cashFund,
              'name': 'صندوق خرید',
              'kind': 'CASH',
              'branchId': branch,
            },
            {
              'fundId': bankFund,
              'name': 'حساب خرید',
              'kind': 'BANK',
              'branchId': null,
            },
          ],
        ],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/warehouses')) {
      return jsonResponse({
        'items': [fixtureResult()['warehouse']],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/branch-access')) {
      return jsonResponse({
        'items': [
          {
            ...(fixtureResult()['branchAccess'] as Map),
            'canReceiveStock': linkReceive,
            'branchAccessId': '44444444-4444-4444-8444-444444444449',
          },
        ],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/suppliers')) {
      return jsonResponse({
        'businessId': 12345678,
        'items': [party],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/suppliers/$supplierId')) {
      return jsonResponse({'businessId': 12345678, 'item': party});
    }
    if (path.endsWith('/v2/invoices') && request.method == 'POST') {
      expect(request.headers['x-app-id'], app);
      expect(request.headers['x-branch-id'], branch);
      final key = request.headers['idempotency-key']!;
      if (receipts.containsKey(key)) return jsonResponse(receipts[key]!, 202);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {
        'type',
        'supplierId',
        'deliveryStatus',
        'lines',
        for (final key in [
          'dueAt',
          'note',
          'discountAmount',
          'shippingAmount',
          'surchargeAmount',
          'taxAmount',
          'purchaseTaxTreatment',
          'payments',
        ])
          if (body.containsKey(key)) key,
      });
      expect(body['type'], 'PURCHASE');
      expect(body['supplierId'], supplierId);
      expect(body['deliveryStatus'], 'DELIVERED');
      final row = (body['lines'] as List).single;
      expect(row.keys.toSet(), {
        'variantId',
        'quantity',
        'unitPrice',
        'warehouseIds',
      });
      expect(row['warehouseIds'], [warehouse]);
      expect(row['unitPrice'], isA<int>());
      expect(row['quantity'], isA<String>());
      final parts = (row['quantity'] as String).split('.');
      final units =
          BigInt.parse(parts[0]) * BigInt.from(1000000) +
          BigInt.parse((parts.length == 1 ? '' : parts[1]).padRight(6, '0'));
      total =
          ((BigInt.from(row['unitPrice'] as int) * units +
                      BigInt.from(500000)) ~/
                  BigInt.from(1000000))
              .toInt();
      total +=
          -(body['discountAmount'] as int? ?? 0) +
          (body['shippingAmount'] as int? ?? 0) +
          (body['surchargeAmount'] as int? ?? 0) +
          (body['taxAmount'] as int? ?? 0);
      for (final payment in body['payments'] as List? ?? []) {
        expect(payment['direction'], 'OUT');
        expect(payment['amount'], isA<int>());
        expect(payment['amount'], greaterThan(0));
        final method = payment['method'];
        expect((payment['routing'] as Map).keys.single, 'fundId');
        expect(
          payment['routing']['fundId'],
          method == 'CASH' ? cashFund : bankFund,
        );
        if (method == 'CHEQUE') {
          expect(payment.containsKey('confirmed'), false);
          expect(payment['cheque']['dueAt'], isA<String>());
        } else {
          expect(payment['confirmed'], true);
          paid += payment['amount'] as int;
        }
      }
      final reply = {'businessId': 12345678, 'operation': operation};
      receipts[key] = reply;
      if (lost) {
        lost = false;
        throw TimeoutException('lost reply');
      }
      return jsonResponse(reply, 202);
    }
    if (path.endsWith('/operations/$operationId')) {
      status = next;
      revision++;
      return jsonResponse({'businessId': 12345678, 'operation': operation});
    }
    if (path.endsWith('/v2/invoices/$invoiceId')) {
      return jsonResponse({
        'businessId': 12345678,
        'invoice': {
          'businessId': 12345678,
          'branchId': branch,
          'invoiceId': invoiceId,
          'type': wrongInvoice ? 'SALE' : 'PURCHASE',
          'deliveryStatus': 'DELIVERED',
          'number': '00000002',
          'status': 'ISSUED',
          'paymentStatus': total == 0 || paid >= total
              ? 'PAID'
              : paid > 0
              ? 'PARTIALLY_PAID'
              : 'UNPAID',
          'totals': {'currency': 'TOMAN', 'total': total},
        },
      });
    }
    for (final resource in [PimResource.products, PimResource.variants]) {
      if (path.endsWith('/${resource.path}')) {
        if (delayed != null && resource == PimResource.products) {
          return delayed!.future;
        }
        return jsonResponse({
          'businessId': 12345678,
          'items': [fixturePim(resource)],
          'nextCursor': null,
        });
      }
    }
    throw StateError('Unexpected purchase path: $path');
  }

  Future<void> prepare() async {
    final context = pimFixture(MockClient(respond), appId: app).context;
    await context.selectBranch((await context.branches()).single);
    requests.clear();
  }

  Future<PurchaseController> draft(List<(String, bool)> notices) async {
    final c = PurchaseController(
      appId: app,
      onNotice: (m, s) => notices.add((m, s)),
    );
    await c.load();
    expect(c.error.value, isNull);
    c.supplier.value = c.suppliers.single;
    await c.open(c.products.single);
    c.add(c.products.single, c.variants.single);
    c.setLine(c.lines.single, quantity: '۱٫۵', price: '۱۰۱');
    return c;
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
      '$app purchase includes the actual outgoing cash or bank payment in its durable invoice request',
      () async {
        final server = PurchaseServer(app)..paymentAllowed = true;
        await server.prepare();
        final c = await server.draft([]);
        addTearDown(c.onClose);
        c.paymentMode.value = 'پرداخت کامل';
        for (final method in ['CASH', 'CARD', 'BANK_TRANSFER']) {
          c.paymentMethod.value = method;
          await c.loadPaymentTargets();
          expect(
            c.paymentTargets.single.kind,
            method == 'CASH' ? 'CASH' : 'BANK',
          );
        }
        c.paymentTarget.value = c.paymentTargets.single;
        server.lost = true;
        await c.submit();
        expect(c.pending.value, isNotNull);
        await c.submit();
        expect(server.receipts.length, 1);
        expect(server.writes.first.body, server.writes.last.body);
        final payment =
            (jsonDecode(server.writes.first.body)['payments'] as List).single;
        expect(payment['method'], 'BANK_TRANSFER');
        expect(payment['amount'], 152);
        expect(c.issued.value!.paymentStatus, 'PAID');
      },
    );
    test(
      '$app purchase combines an initial payment and a pending cheque, validates the plan and rechecks bank access',
      () async {
        final server = PurchaseServer(app)..paymentAllowed = true;
        await server.prepare();
        final c = await server.draft([]);
        addTearDown(c.onClose);
        c.paymentMode.value = 'بخشی از مبلغ';
        c.paymentAmount.value = '50';
        await c.loadPaymentTargets();
        c.paymentTarget.value = c.paymentTargets.single;
        final banks = await c.invoices!.paymentTargets('CHEQUE');
        expect(c.addChequePayment(banks.single, '100'), false);
        c.cheque.assignAll({
          'bankName': 'بانک نمونه',
          'number': '123',
          'sayadId': '1234567890123456',
        });
        c.chequeDueAt.value = DateTime.utc(2026, 12, 1);
        expect(c.addChequePayment(banks.single, '100'), true);
        expect(c.scheduledAmount, 150);
        expect(c.canSubmit, true);
        c.paymentAmount.value = '60';
        expect(c.canSubmit, false);
        c.paymentAmount.value = '50';
        await c.submit();
        final payments =
            jsonDecode(server.writes.single.body)['payments'] as List;
        expect(payments.length, 2);
        expect(payments[0]['method'], 'CASH');
        expect(payments[1]['method'], 'CHEQUE');
        expect(payments[1]['amount'], 100);
        expect(c.issued.value!.paymentStatus, 'PARTIALLY_PAID');
      },
    );
    test(
      '$app purchase payment refuses unavailable sources and revoked permissions before sending an invoice',
      () async {
        final server = PurchaseServer(app)..paymentAllowed = true;
        await server.prepare();
        final c = await server.draft([]);
        addTearDown(c.onClose);
        c.paymentMode.value = 'پرداخت کامل';
        await c.loadPaymentTargets();
        c.paymentTarget.value = c.paymentTargets.single;
        server.targetsAvailable = false;
        await c.submit();
        expect(server.writes, isEmpty);
        expect(c.paymentTarget.value, isNull);
        server.targetsAvailable = true;
        await c.loadPaymentTargets();
        c.paymentTarget.value = c.paymentTargets.single;
        server.paymentAllowed = false;
        await c.submit();
        expect(server.writes, isEmpty);
        expect(c.pending.value, isNull);
      },
    );
    test(
      '$app purchase costs require explicit tax treatment and use the final amount',
      () async {
        final server = PurchaseServer(app)..amountPermissions = true;
        await server.prepare();
        final c = await server.draft([]);
        addTearDown(c.onClose);
        c.amounts.value = const InvoiceAmounts(
          discount: 2,
          shipping: 10,
          surcharge: 3,
          tax: 7,
        );
        expect(c.canSubmit, isFalse);
        await c.submit();
        expect(server.writes, isEmpty);
        c.amounts.value = const InvoiceAmounts(
          discount: 2,
          shipping: 10,
          surcharge: 3,
          tax: 7,
          purchaseTaxTreatment: 'NON_RECOVERABLE',
        );
        c.dueAt.value = DateTime.utc(2026, 11, 20, 12, 30);
        c.note.value = '  یادداشت خرید  ';
        expect(c.total, 170);
        await c.submit();
        expect(c.issued.value!.total, 170);
        final saved = jsonDecode(server.writes.single.body) as Map;
        expect(saved['dueAt'], '2026-11-20T12:30:00.000Z');
        expect(saved['note'], 'یادداشت خرید');
        expect(
          (jsonDecode(server.writes.single.body)
              as Map)['purchaseTaxTreatment'],
          'NON_RECOVERABLE',
        );
      },
    );

    test(
      '$app purchase validates money and quantity, resumes exact request and confirms final invoice',
      () async {
        final server = PurchaseServer(app);
        await server.prepare();
        final notices = <(String, bool)>[];
        final c = await server.draft(notices);
        addTearDown(c.onClose);
        expect(c.total, 152);
        for (final price in ['', '-1', '1.5', '9007199254740992']) {
          c.setLine(c.lines.single, price: price);
          expect(c.canSubmit, isFalse);
        }
        c.setLine(c.lines.single, price: '101', quantity: '0');
        expect(c.canSubmit, isFalse);
        notices.clear();
        await c.submit();
        expect(server.writes, isEmpty);
        expect(notices.last.$2, isFalse);
        c.setLine(c.lines.single, quantity: '1.5');
        server.lost = true;
        notices.clear();
        await c.submit();
        expect(c.pending.value, isNotNull);
        expect(c.issued.value, isNull);
        expect(notices.last.$2, isFalse);
        final resumed = PurchaseController(
          appId: app,
          onNotice: (m, s) => notices.add((m, s)),
        );
        addTearDown(resumed.onClose);
        await resumed.load();
        expect(resumed.pending.value, isNotNull);
        notices.clear();
        await resumed.submit();
        expect(resumed.issued.value!.total, 152);
        expect(notices.last.$2, isTrue);
        expect(server.receipts.length, 1);
        expect(server.writes.length, 2);
        expect(server.writes.first.body, server.writes.last.body);
        expect(
          server.writes.first.headers['idempotency-key'],
          server.writes.last.headers['idempotency-key'],
        );
        await resumed.reset();
        expect(resumed.pending.value, isNull);
      },
    );
    test(
      '$app purchase denies inaccessible warehouse and never reports pending or malformed invoice as success',
      () async {
        final server = PurchaseServer(app)..linkReceive = false;
        await server.prepare();
        final notices = <(String, bool)>[];
        final c = PurchaseController(
          appId: app,
          onNotice: (m, s) => notices.add((m, s)),
        );
        addTearDown(c.onClose);
        await c.load();
        expect(c.warehouses, isEmpty);
        expect(BusinessContext.forApp(app)!.selectedBranch?.branchId, branch);
        expect(c.error.value, contains('انبار مجاز ورود'));
        server.linkReceive = true;
        server.receive = false;
        await c.load();
        expect(c.error.value, isNotNull);
        expect(server.writes, isEmpty);
        server.receive = true;
        await c.load();
        expect(c.error.value, isNull);
        expect(
          server.requests.where((r) => r.url.path.endsWith('/branch-access')),
          isEmpty,
        );
        c.supplier.value = c.suppliers.single;
        await c.open(c.products.single);
        c.add(c.products.single, c.variants.single);
        c.setLine(c.lines.single, price: '100');
        server.next = 'ACTION_REQUIRED';
        notices.clear();
        await c.submit();
        expect(c.issued.value, isNull);
        expect(c.locked, isTrue);
        expect(notices.last.$2, isFalse);
        server.next = 'SUCCEEDED';
        server.wrongInvoice = true;
        notices.clear();
        await c.submit();
        expect(c.issued.value, isNull);
        expect(notices.last.$2, isFalse);
        BusinessContext.forApp(app)!.clearAccess();
        notices.clear();
        await c.submit();
        expect(c.lines, isEmpty);
        expect(c.pending.value, isNull);
        expect(notices.last.$2, isFalse);
      },
    );
    testWidgets(
      '$app purchase native form selects supplier and variant, requires explicit cost and shows validation Alert',
      (tester) async {
        final server = PurchaseServer(app)..paymentAllowed = true;
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
              home: Scaffold(body: PurchaseInvoiceProducts(appId: app)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.byKey(const ValueKey('invoice-party-picker')));
        await tester.pumpAndSettle();
        expect(find.text('تامین‌کنندگان (1)'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('invoice-supplier-$supplierId')),
        );
        await tester.pumpAndSettle();
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(
          find.byKey(const ValueKey('invoice-warehouse-picker')),
        );
        await tester.pumpAndSettle();
        expect(find.text('انتخاب انبار'), findsOneWidget);
        final searchWarehouse = find.descendant(
          of: find.byType(MySearchBar),
          matching: find.byType(TextField),
        );
        await tester.enterText(searchWarehouse, 'انبار ناموجود');
        await tester.pumpAndSettle();
        expect(find.text('انبار با این نام وجود ندارد!'), findsOneWidget);
        await tester.enterText(searchWarehouse, '');
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('invoice-warehouse-$warehouse')),
        );
        await tester.pumpAndSettle();
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('افزودن کالا'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('پیراهن'));
        await tester.pumpAndSettle();
        final variant = PimVariant.fromJson(fixturePim(PimResource.variants));
        await tester.tap(find.text(variant.name));
        await tester.pumpAndSettle();
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('تایید انتخاب شده‌ها'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductItemInvoice), findsOneWidget);
        await tester.tap(find.text('ادامه'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'تامین‌کننده، انبار مقصد، تعداد و قیمت خرید اقلام را کامل کنید.',
          ),
          findsOneWidget,
        );
        expect(server.writes, isEmpty);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(
          find.byKey(const ValueKey('purchase-price-control-$variantId')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('purchase-price-$variantId')),
            matching: find.byType(TextField),
          ),
          '100',
        );
        await tester.tap(find.text('تایید قیمت'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ادامه'));
        await tester.pumpAndSettle();
        expect(find.text('تکمیل فاکتور'), findsOneWidget);
        expect(find.text('اقساطی'), findsOneWidget);
        await tester.ensureVisible(find.text('نقدی'));
        await tester.tap(find.text('نقدی'));
        await tester.pumpAndSettle();
        final source = find.byKey(
          const ValueKey('purchase-payment-target-CASH'),
        );
        await tester.ensureVisible(source);
        await tester.tap(source);
        await tester.pumpAndSettle();
        await tester.tap(find.text('صندوق خرید').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('ثبت فاکتور'));
        await tester.tap(find.text('ثبت فاکتور'));
        await tester.pumpAndSettle();
        expect(find.text('ثبت نهایی'), findsWidgets);
        await tester.tap(find.text('ثبت نهایی').last);
        await tester.pumpAndSettle();
        expect(find.text('شماره فاکتور: 00000002'), findsOneWidget);
        expect(
          (jsonDecode(server.writes.single.body)['payments'] as List)
              .single['method'],
          'CASH',
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
