import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';
import 'package:mik_pages/invoice/add/components/selectproduct.dart';
import 'package:mik_pages/invoice/add/components/item/item.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_data/source/remote/models/invoice_amounts.dart';

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/source/remote/models/customer.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/invoice/add/sale_products.dart';
import 'package:mik_pages/invoice/add/sale_products_controller.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const cashFund = '55555555-5555-4555-8555-555555555559';
const bankFund = '66666666-6666-4666-8666-666666666669';
const terminalId = '77777777-7777-4777-8777-777777777779';
const customerId = '11111111-1111-4111-8111-111111111119';
const operationId = '22222222-2222-4222-8222-222222222229';
const invoiceId = '33333333-3333-4333-8333-333333333339';
Map<String, dynamic> customer() => {
  'businessId': 12345678,
  'customerId': customerId,
  'name': 'مشتری نمونه',
  'phone': '+989000000011',
  'kind': 'PERSON',
  'status': 'ACTIVE',
  'revision': 1,
  'isDefault': false,
  'assignedMembershipIds': [],
  'createdBy': {'identityId': identity},
};

class SaleServer {
  final String app;
  SaleServer(this.app);
  final requests = <http.Request>[];
  bool amountPermissions = false;
  bool allowed = true, missingPrice = false;
  bool paymentAllowed = true,
      creditAllowed = true,
      emptyTargets = false,
      wrongTargetBranch = false;
  bool invoicePaid = false;
  bool lostResponse = false, delivered = true;
  int amount = 0, invoiceTotal = 0, operationRevision = 1;
  String operationStatus = 'PENDING', nextStatus = 'SUCCEEDED';
  final receipts = <String, Map<String, dynamic>>{};
  List<http.Request> get mutations =>
      requests.where((r) => r.method == 'POST').toList();
  Map<String, dynamic> operation() => {
    'operationId': operationId,
    'command': 'invoice.create.v2',
    'status': operationStatus,
    'revision': operationRevision,
    if (operationStatus == 'SUCCEEDED')
      'result': {
        'invoiceId': invoiceId,
        'rootInvoiceId': invoiceId,
        'revision': 2,
      },
    if (operationStatus == 'FAILED') 'errorCode': 'INSUFFICIENT_STOCK',
  };
  Completer<http.Response>? pending;
  Map<String, Object> get effective => {
    'businessId': 12345678,
    'productId': productId,
    'variantId': variantId,
    'productPriceId': priceId,
    'amount': amount,
    'currency': 'TOMAN',
    'source': 'VARIANT_OVERRIDE',
  };
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final scope = request.url.queryParameters['scopeType'];
      return jsonResponse({
        ...fixtureAuthorization(
          scope == 'BRANCH'
              ? (allowed
                    ? [
                        'accounting.sale.create',
                        'accounting.sale.read',
                        if (amountPermissions) ...[
                          'accounting.sale.discount.apply',
                          'accounting.sale.surcharge.apply',
                        ],
                        if (paymentAllowed) ...[
                          'accounting.payment.allocate',
                          'accounting.sale.payment.receive',
                          'accounting.treasury.use',
                        ],
                        if (delivered) 'accounting.sale.status.delivered',
                      ]
                    : [])
              : [
                  'pim.product.read',
                  'pim.variant.read',
                  'pim.price.read',
                  'ucrm.customer.read',
                  if (paymentAllowed) ...[
                    'accounting.payment.create',
                    'accounting.bank.use',
                  ],
                ],
        ),
        'scopeType': scope,
        'scopeId': request.url.queryParameters['scopeId'],
      });
    }
    if (path.endsWith('/treasury/options')) {
      expect(
        request.url.queryParameters.keys.toSet().difference({
          'kind',
          'limit',
          'after',
        }),
        isEmpty,
      );
      final isTerminal = request.url.queryParameters['kind'] == 'terminal';
      final after = request.url.queryParameters['after'];
      return jsonResponse({
        'businessId': 12345678,
        'items': emptyTargets
            ? []
            : isTerminal
            ? [
                {
                  'terminalId': terminalId,
                  'name': 'پایانه نمونه',
                  'fundId': bankFund,
                  'branchId': wrongTargetBranch ? customerId : branch,
                },
              ]
            : after == null
            ? [
                {
                  'fundId': cashFund,
                  'name': 'صندوق نمونه',
                  'kind': 'CASH',
                  'branchId': wrongTargetBranch ? customerId : branch,
                },
              ]
            : [
                {'fundId': bankFund, 'name': 'بانک نمونه', 'kind': 'BANK'},
              ],
        'nextCursor': !emptyTargets && !isTerminal && after == null
            ? cashFund
            : null,
      });
    }
    if (path.endsWith('/branches')) {
      return jsonResponse({
        'items': [fixtureResult()['branch']],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/customers')) {
      return jsonResponse({
        'businessId': 12345678,
        'items': [customer()],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/customers/$customerId')) {
      return jsonResponse({'businessId': 12345678, 'customer': customer()});
    }
    if (path.endsWith('/accounting/v2/invoices') && request.method == 'POST') {
      final key = request.headers['idempotency-key']!;
      if (receipts.containsKey(key)) return jsonResponse(receipts[key]!, 202);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {
        'type',
        'customerId',
        'deliveryStatus',
        'lines',
        if (body.containsKey('payments')) 'payments',
        for (final key in [
          'dueAt',
          'note',
          'discountAmount',
          'shippingAmount',
          'surchargeAmount',
          'taxAmount',
        ])
          if (body.containsKey(key)) key,
      });
      expect(body['type'], 'SALE');
      expect(body['customerId'], customerId);
      expect(body['deliveryStatus'], 'DELIVERED');
      expect((body['lines'] as List).single.keys.toSet(), {
        'variantId',
        'quantity',
        'productPriceId',
      });
      invoiceTotal =
          (amount *
                  double.parse(
                    (body['lines'] as List).single['quantity'] as String,
                  ))
              .round();
      invoiceTotal +=
          -(body['discountAmount'] as int? ?? 0) +
          (body['shippingAmount'] as int? ?? 0) +
          (body['surchargeAmount'] as int? ?? 0) +
          (body['taxAmount'] as int? ?? 0);
      invoicePaid = body.containsKey('payments');
      if (!invoicePaid && invoiceTotal > 0 && !creditAllowed) {
        return jsonResponse({
          'error': {'code': 'CREDIT_SALES_DISABLED'},
        }, 400);
      }
      if (invoicePaid) {
        final payment = (body['payments'] as List).single;
        expect(payment['amount'], invoiceTotal);
        expect(payment['confirmed'], isTrue);
        expect(payment['direction'], 'IN');
        expect(
          payment['routing'],
          payment['method'] == 'CARD'
              ? {'terminalId': terminalId}
              : {'fundId': payment['method'] == 'CASH' ? cashFund : bankFund},
        );
      }
      final reply = {
        'businessId': 12345678,
        'operation': operation(),
        'replayed': false,
      };
      receipts[key] = reply;
      if (lostResponse) {
        lostResponse = false;
        throw TimeoutException('lost response');
      }
      return jsonResponse(reply, 202);
    }
    if (path.endsWith('/operations/$operationId')) {
      operationStatus = nextStatus;
      operationRevision++;
      return jsonResponse({'businessId': 12345678, 'operation': operation()});
    }
    if (path.endsWith('/v2/invoices/$invoiceId')) {
      return jsonResponse({
        'businessId': 12345678,
        'invoice': {
          'businessId': 12345678,
          'invoiceId': invoiceId,
          'branchId': branch,
          'type': 'SALE',
          'number': '00000001',
          'status': 'ISSUED',
          'paymentStatus': invoiceTotal == 0 || invoicePaid ? 'PAID' : 'UNPAID',
          'totals': {'currency': 'TOMAN', 'total': invoiceTotal},
        },
      });
    }
    for (final resource in [
      PimResource.products,
      PimResource.variants,
      PimResource.prices,
    ]) {
      if (path.endsWith('/${resource.path}')) {
        expect(request.url.queryParameters['status'], 'ACTIVE');
        if (resource != PimResource.products) {
          expect(request.url.queryParameters['productId'], productId);
        }
        return jsonResponse(fixturePimPage(resource));
      }
    }
    if (path.endsWith('/price')) {
      if (pending != null) return pending!.future;
      if (missingPrice) {
        return jsonResponse({
          'error': {'code': 'PRICE_NOT_FOUND'},
        }, 404);
      }
      return jsonResponse(effective);
    }
    throw StateError('Unexpected request: $path');
  }

  Future<void> prepare() async {
    final fx = pimFixture(MockClient(respond), appId: app);
    await fx.authorize();
    await fx.context.selectBranch((await fx.context.branches()).single);
    requests.clear();
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
      '$app final sale payment includes permitted invoice adjustments and preserves them on retry',
      () async {
        final server = SaleServer(app)
          ..amount = 100
          ..amountPermissions = true;
        await server.prepare();
        final errors = <String>[];
        final c = SaleProductsController(appId: app, onError: errors.add);
        addTearDown(c.onClose);
        await c.load();
        await c.open(c.products.single);
        c.lines.add((await c.choose(c.products.single, c.variants.single))!);
        c.customer.value = RemoteCustomer.fromJson(customer());
        c.paymentTarget.value = c.paymentTargets.single;
        c.amounts.value = const InvoiceAmounts(
          discount: 10,
          shipping: 20,
          surcharge: 3,
          tax: 7,
        );
        c.dueAt.value = DateTime.utc(2026, 11, 20, 12, 30);
        c.note.value = '  یادداشت فروش  ';
        expect(c.subtotal, 100);
        expect(c.total, 120);
        c.note.value = 'x' * 1001;
        await c.submit(receiptConfirmed: true);
        expect(server.mutations, isEmpty);
        c.note.value = '  یادداشت فروش  ';
        server.lostResponse = true;
        await c.submit(receiptConfirmed: true);
        expect(c.pendingSale.value!.body['discountAmount'], 10);
        expect(c.pendingSale.value!.body['dueAt'], '2026-11-20T12:30:00.000Z');
        expect(c.pendingSale.value!.body['note'], 'یادداشت فروش');
        await c.submit();
        expect(c.issued.value!.total, 120);
        expect(server.mutations.first.body, server.mutations.last.body);
        final row = c.lines.single;
        await c.resetFinished();
        expect(c.amounts.value.payload, isEmpty);
        expect(c.dueAt.value, isNull);
        expect(c.note.value, isEmpty);
        c.lines.add(row);
        c.customer.value = RemoteCustomer.fromJson(customer());
        c.amounts.value = const InvoiceAmounts(discount: 1);
        server.amountPermissions = false;
        final writes = server.mutations.length;
        await c.submit(receiptConfirmed: true);
        expect(server.mutations.length, writes);
        expect(errors.last, isNotEmpty);
      },
    );

    test(
      '$app actual full receipt supports each route and resumes the exact confirmed payment',
      () async {
        final server = SaleServer(app)
          ..amount = 125
          ..creditAllowed = false;
        await server.prepare();
        final errors = <String>[], successes = <String>[];
        final c = SaleProductsController(
          appId: app,
          onError: errors.add,
          onSuccess: successes.add,
        );
        addTearDown(c.onClose);
        await c.load();
        expect(errors, isEmpty);
        expect(successes, isEmpty);
        await c.open(c.products.single);
        final row = (await c.choose(c.products.single, c.variants.single))!;
        c.lines.add(row);
        c.customer.value = RemoteCustomer.fromJson(customer());
        expect(c.canSubmit, isFalse);
        c.paymentTarget.value = c.paymentTargets.single;
        await c.submit();
        expect(server.mutations, isEmpty);
        expect(errors.last, contains('تایید دریافت واقعی'));
        server.lostResponse = true;
        await c.submit(receiptConfirmed: true);
        expect(c.issued.value, isNull);
        expect(c.pendingSale.value, isNotNull);
        expect(successes, isEmpty);
        final restored = SaleProductsController(
          appId: app,
          onSuccess: successes.add,
        );
        addTearDown(restored.onClose);
        await restored.load();
        await restored.submit();
        expect(restored.issued.value!.paymentStatus, 'PAID');
        expect(successes.single, contains('تسویه‌شده'));
        expect(server.mutations.length, 2);
        expect(server.mutations.first.body, server.mutations.last.body);
        expect(
          server.mutations.first.headers['idempotency-key'],
          server.mutations.last.headers['idempotency-key'],
        );
        for (final method in ['BANK_TRANSFER', 'CARD']) {
          await restored.resetFinished();
          restored.paymentMethod.value = method;
          await restored.loadPaymentTargets();
          restored.paymentTarget.value = restored.paymentTargets.single;
          restored.lines.add(row);
          restored.customer.value = RemoteCustomer.fromJson(customer());
          await restored.submit(receiptConfirmed: true);
          expect(restored.issued.value!.paymentStatus, 'PAID');
          expect(
            jsonDecode(server.mutations.last.body)['payments'].single['method'],
            method,
          );
        }
      },
    );
    test(
      '$app receipt refuses revoked grants, another branch and removed destination without silent credit fallback',
      () async {
        final server = SaleServer(app)..amount = 100;
        await server.prepare();
        final errors = <String>[];
        final c = SaleProductsController(appId: app, onError: errors.add);
        addTearDown(c.onClose);
        await c.load();
        await c.open(c.products.single);
        c.lines.add((await c.choose(c.products.single, c.variants.single))!);
        c.customer.value = RemoteCustomer.fromJson(customer());
        c.paymentTarget.value = c.paymentTargets.single;
        server.emptyTargets = true;
        await c.submit(receiptConfirmed: true);
        expect(server.mutations, isEmpty);
        expect(c.paymentTarget.value, isNull);
        expect(errors.last, contains('دوباره انتخاب'));
        server.emptyTargets = false;
        server.wrongTargetBranch = true;
        await c.loadPaymentTargets();
        expect(c.paymentTargets, isEmpty);
        expect(server.mutations, isEmpty);
        server.wrongTargetBranch = false;
        server.paymentAllowed = false;
        await c.loadPaymentTargets();
        expect(errors.last, contains('مجوز'));
        expect(server.mutations, isEmpty);
        expect(c.paymentMode.value, 'دریافت کامل');
      },
    );
    test(
      '$app exact quantity and refreshed prices require review before confirmed v2 issuance',
      () async {
        final server = SaleServer(app)..amount = 1;
        await server.prepare();
        final errors = <String>[];
        final c = SaleProductsController(appId: app, onError: errors.add);
        addTearDown(c.onClose);
        c.paymentMode.value = 'اعتباری';
        await c.load();
        await c.open(c.products.single);
        final row = await c.choose(c.products.single, c.variants.single);
        c.lines.add(row!);
        c.customer.value = RemoteCustomer.fromJson(customer());
        c.setQuantity(variantId, '۲٫۵۰۰۰۰۰');
        expect(c.lines.single.quantity, '2.5');
        expect(c.lines.single.amount, 3);
        c.setQuantity(variantId, '0');
        expect(c.subtotal, isNull);
        expect(c.canSubmit, isFalse);
        c.setQuantity(variantId, '1.1234567');
        expect(c.subtotal, isNull);
        c.setQuantity(variantId, '2.5');
        server.amount = 2;
        await c.submit();
        expect(server.mutations, isEmpty);
        expect(c.error.value, contains('قیمت اقلام تغییر کرده'));
        expect(errors.single, c.error.value);
        expect(c.subtotal, 5);
        await c.submit();
        expect(server.mutations.length, 1);
        expect(c.issued.value!.id, invoiceId);
        expect(c.issued.value!.total, 5);
        expect(c.operation.value!.status, 'SUCCEEDED');
        expect(c.pendingSale.value, isNotNull);
        expect(c.locked, isTrue);
        expect(server.mutations.single.headers['x-branch-id'], branch);
        expect(server.mutations.single.headers['x-app-id'], app);
        await c.resetFinished();
        expect(c.pendingSale.value, isNull);
        expect(c.lines, isEmpty);
      },
    );
    test(
      '$app lost response restores exact command; operation failure never creates another invoice',
      () async {
        final server = SaleServer(app)..lostResponse = true;
        await server.prepare();
        final c = SaleProductsController(appId: app);
        addTearDown(c.onClose);
        c.paymentMode.value = 'اعتباری';
        await c.load();
        await c.open(c.products.single);
        c.lines.add((await c.choose(c.products.single, c.variants.single))!);
        c.customer.value = RemoteCustomer.fromJson(customer());
        await c.submit();
        expect(c.issued.value, isNull);
        expect(c.pendingSale.value, isNotNull);
        final errors = <String>[];
        final restored = SaleProductsController(
          appId: app,
          onError: errors.add,
        );
        addTearDown(restored.onClose);
        await restored.load();
        expect(restored.pendingSale.value, isNotNull);
        server.nextStatus = 'FAILED';
        await restored.submit();
        expect(server.mutations.length, 2);
        expect(server.mutations[0].body, server.mutations[1].body);
        expect(
          server.mutations[0].headers['idempotency-key'],
          server.mutations[1].headers['idempotency-key'],
        );
        expect(server.receipts.length, 1);
        expect(restored.operation.value!.status, 'FAILED');
        expect(errors.last, contains('موجودی قابل فروش'));
        expect(restored.issued.value, isNull);
        expect(restored.locked, isTrue);
        await restored.submit();
        expect(server.mutations.length, 2);
        await restored.resetFinished();
        expect(restored.locked, isFalse);
      },
    );
    test(
      '$app missing price, revoked grant and branch switch cannot register a stale selection',
      () async {
        final server = SaleServer(app);
        await server.prepare();
        final c = SaleProductsController(appId: app);
        addTearDown(c.onClose);
        c.paymentMode.value = 'اعتباری';
        await c.load();
        await c.open(c.products.single);
        server.missingPrice = true;
        expect(await c.choose(c.products.single, c.variants.single), isNull);
        server.missingPrice = false;
        c.lines.add((await c.choose(c.products.single, c.variants.single))!);
        c.customer.value = RemoteCustomer.fromJson(customer());
        server.delivered = false;
        await c.submit();
        expect(server.mutations, isEmpty);
        expect(c.lines, isEmpty);
        server.delivered = true;
        await c.load();
        await c.open(c.products.single);
        c.lines.add((await c.choose(c.products.single, c.variants.single))!);
        c.customer.value = RemoteCustomer.fromJson(customer());
        server.pending = Completer<http.Response>();
        final count = server.requests
            .where((r) => r.url.path.endsWith('/price'))
            .length;
        final submit = c.submit();
        while (server.requests
                .where((r) => r.url.path.endsWith('/price'))
                .length ==
            count) {
          await Future<void>.delayed(Duration.zero);
        }
        BusinessContext.forApp(app)!.clearAccess();
        server.pending!.complete(jsonResponse(server.effective));
        await submit;
        expect(server.mutations, isEmpty);
        expect(c.issued.value, isNull);
        expect(c.lines, isEmpty);
      },
    );
    testWidgets(
      '$app native customer/product picker registers and displays confirmed server invoice',
      (tester) async {
        final server = SaleServer(app)
          ..amount = 100
          ..creditAllowed = false
          ..amountPermissions = true;
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
              home: Scaffold(body: SaleInvoiceProducts(appId: app)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('افزودن کالا'));
        await tester.pumpAndSettle();
        expect(find.byType(SelectProductForInvoice), findsOneWidget);
        expect(find.byType(ProductItemSelect), findsWidgets);
        await tester.tap(find.text('پیراهن'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SHIRT-1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('تایید انتخاب شده‌ها'));
        await tester.pumpAndSettle();
        expect(find.text('پیراهن'), findsOneWidget);
        expect(find.byType(ProductItemInvoice), findsOneWidget);
        final next = tester
            .widgetList<BTN>(find.byType(BTN))
            .singleWhere((b) => b.name == 'ادامه');
        expect(next.disabled, isFalse);
        await tester.tap(find.text('ادامه'));
        await tester.pumpAndSettle();
        expect(find.text('مشتری فاکتور را انتخاب کنید.'), findsNWidgets(2));
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        expect(server.requests.every((r) => r.method == 'GET'), isTrue);
        await tester.tap(find.byKey(const ValueKey('invoice-party-picker')));
        await tester.pumpAndSettle();
        expect(find.text('مشتریان (1)'), findsOneWidget);
        await tester.tap(find.text('انصراف'));
        await tester.pumpAndSettle();
        expect(find.text('پیراهن'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('invoice-party-picker')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('sale-customer-$customerId')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('sale-quantity-$variantId')),
        );
        await tester.pumpAndSettle();
        final quantity = find.descendant(
          of: find.byKey(const ValueKey('invoice-quantity-editor')),
          matching: find.byType(TextField),
        );
        await tester.enterText(quantity, '2');
        await tester.tap(find.text('تایید تعداد'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ادامه'));
        await tester.pumpAndSettle();
        expect(find.text('تکمیل فاکتور'), findsOneWidget);
        expect(find.text('تخفیف و هزینه‌ها'), findsNothing);
        expect(find.byType(PriceInput), findsNWidgets(4));
        final discount = find.descendant(
          of: find.byKey(const ValueKey('invoice-amount-0')),
          matching: find.byType(TextField),
        );
        await tester.enterText(discount, '201');
        await tester.ensureVisible(find.text('ثبت فاکتور'));
        await tester.tap(find.text('ثبت فاکتور'));
        await tester.pumpAndSettle();
        expect(server.mutations, isEmpty);
        expect(find.text('تکمیل فاکتور'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.ensureVisible(discount);
        await tester.enterText(discount, '0');
        final note = find.descendant(
          of: find.byKey(const ValueKey('invoice-note')),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(note);
        await tester.enterText(note, 'توضیح مرحله دوم');
        await tester.ensureVisible(
          find.byKey(const ValueKey('sale-payment-target-CASH')),
        );

        await tester.tap(
          find.byKey(const ValueKey('sale-payment-target-CASH')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('صندوق نمونه').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ثبت فاکتور'));
        await tester.tap(find.text('ثبت فاکتور'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ثبت نهایی'));
        await tester.pumpAndSettle();
        expect(find.text('شماره فاکتور: 00000001'), findsOneWidget);
        expect(server.mutations.length, 1);
        expect(
          jsonDecode(server.mutations.single.body)['note'],
          'توضیح مرحله دوم',
        );

        expect(
          jsonDecode(server.mutations.single.body)['payments'].single['amount'],
          200,
        );
        expect(find.text('تسویه: تسویه‌شده'), findsOneWidget);
        expect(
          server.requests
              .where((r) => r.url.path.contains('/accounting/'))
              .every(
                (r) => r.method == 'GET' || r.url.path.endsWith('/v2/invoices'),
              ),
          isTrue,
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
