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
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/customer.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/invoice_change.dart';
import 'package:mik_pages/invoice/add/sale_products.dart';
import 'package:mik_pages/invoice/add/sale_products_controller.dart';
import 'package:mik_pages/invoice/change_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'invoice_sale_products_test.dart' as sale;
import 'invoice_change_test.dart' as change;
import 'invoice_read_test.dart' show invoiceOne, invoiceTwo;

class ProformaCreateServer extends sale.SaleServer {
  ProformaCreateServer(super.app) {
    amount = 100;
    paymentAllowed = false;
    creditAllowed = false;
  }
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final codes = json['permissionCodes'] as List;
      codes.removeWhere((v) => v.toString().startsWith('accounting.sale.'));
      if (allowed) {
        codes.addAll([
          'accounting.proforma.create',
          'accounting.proforma.read',
        ]);
      }
      return jsonResponse(json);
    }
    if (path.endsWith('/v2/invoices') && request.method == 'POST') {
      requests.add(request);
      final key = request.headers['idempotency-key']!;
      if (receipts.containsKey(key)) return jsonResponse(receipts[key]!, 202);
      final body = jsonDecode(request.body) as Map;
      expect(body['type'], 'PROFORMA');
      expect(body['deliveryStatus'], 'PENDING');
      expect(body.containsKey('payments'), isFalse);
      expect(body['customerId'], sale.customerId);
      expect(DateTime.parse(body['validUntil'] as String).isUtc, isTrue);
      invoiceTotal = 100;
      final reply = <String, dynamic>{
        'businessId': 12345678,
        'operation': operation(),
      };
      receipts[key] = reply;
      if (lostResponse) {
        lostResponse = false;
        throw TimeoutException('lost');
      }
      return jsonResponse(reply, 202);
    }
    if (path.endsWith('/v2/invoices/${sale.invoiceId}')) {
      requests.add(request);
      return jsonResponse({
        'businessId': 12345678,
        'invoice': {
          'businessId': 12345678,
          'invoiceId': sale.invoiceId,
          'branchId': branch,
          'type': 'PROFORMA',
          'number': 'PF-1',
          'status': 'ISSUED',
          'deliveryStatus': 'PENDING',
          'paymentStatus': 'UNPAID',
          'totals': {'currency': 'TOMAN', 'total': 100},
        },
      });
    }
    return super.respond(request);
  }
}

class ProformaChangeServer extends change.ChangeServer {
  ProformaChangeServer(super.app) : super(documentType: 'PROFORMA') {
    posted = false;
  }
  bool expired = false, brokenLink = false;
  @override
  Map<String, Object?> detail(String type) => {
    ...super.detail(type),
    'deliveryStatus': 'PENDING',
    'validUntil': expired
        ? '2020-01-01T00:00:00.000Z'
        : '2099-01-01T00:00:00.000Z',
    if (documentStatus == 'CONVERTED') 'convertedInvoiceId': invoiceTwo,
  };
  @override
  Map<String, dynamic> operation({bool done = false}) => {
    ...super.operation(done: done),
    if (done && !failed && action == 'convert')
      'result': {
        'invoiceId': invoiceTwo,
        'rootInvoiceId': invoiceTwo,
        'revision': 2,
      },
  };
  @override
  void complete() {
    if (action == 'convert') {
      if (!finished) {
        finished = true;
        revision++;
        documentStatus = 'CONVERTED';
      }
    } else {
      super.complete();
    }
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (write) {
        (json['permissionCodes'] as List).addAll([
          'accounting.proforma.update',
          'accounting.proforma.update.all',
          'accounting.proforma.convert',
          'accounting.sale.create',
          'accounting.payment.allocate',
          'accounting.sale.payment.receive',
          'accounting.treasury.use',
          'accounting.payment.create',
        ]);
      }
      return jsonResponse(json);
    }
    if (path.endsWith('/treasury/options')) {
      requests.add(request);
      return jsonResponse({
        'businessId': 12345678,
        'items': [
          {
            'fundId': sale.cashFund,
            'name': 'صندوق نمونه',
            'kind': 'CASH',
            'branchId': branch,
          },
        ],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/v2/invoices/$invoiceTwo')) {
      requests.add(request);
      return jsonResponse({
        'businessId': 12345678,
        'invoice': {
          ...super.detail('SALE'),
          'invoiceId': invoiceTwo,
          'rootInvoiceId': invoiceTwo,
          'type': 'SALE',
          'status': 'ISSUED',
          'revision': 2,
          'referenceInvoiceId': brokenLink ? invoiceTwo : invoiceOne,
        },
      });
    }
    if (request.method == 'POST' && path.endsWith('/invoices/convert')) {
      final key = request.headers['idempotency-key']!;
      if (!receipts.containsKey(key) && expired) {
        requests.add(request);
        return jsonResponse({
          'error': {'code': 'PROFORMA_EXPIRED'},
        }, 409);
      }
    }
    return super.respond(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var dir = Directory.current;
    while (!File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
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
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app proforma needs no sale or payment grants and replays exact create',
      () async {
        final server = ProformaCreateServer(app);
        await server.prepare();
        final errors = <String>[], notices = <String>[];
        final c = SaleProductsController(
          appId: app,
          type: 'PROFORMA',
          onError: errors.add,
          onSuccess: notices.add,
        );
        addTearDown(c.onClose);
        await c.load();
        expect(errors, isEmpty);
        expect(
          server.requests.any((r) => r.url.path.contains('/treasury')),
          isFalse,
        );
        await c.open(c.products.single);
        c.lines.add((await c.choose(c.products.single, c.variants.single))!);
        c.customer.value = RemoteCustomer.fromJson(sale.customer());
        c.validUntil.value = DateTime.utc(2020);
        expect(c.canSubmit, isFalse);
        await c.submit();
        expect(server.mutations, isEmpty);
        c.validUntil.value = DateTime.utc(2099);
        expect(c.canSubmit, isTrue);
        server.lostResponse = true;
        await c.submit();
        expect(c.pendingSale.value, isNotNull);
        final resumed = SaleProductsController(
          appId: app,
          type: 'PROFORMA',
          onSuccess: notices.add,
        );
        addTearDown(resumed.onClose);
        await resumed.load();
        await resumed.submit();
        expect(resumed.issued.value!.number, 'PF-1');
        expect(notices.single, contains('پیش‌فاکتور'));
        expect(server.mutations.length, 2);
        expect(server.mutations.first.body, server.mutations.last.body);
        expect(
          server.mutations.first.headers['idempotency-key'],
          server.mutations.last.headers['idempotency-key'],
        );
      },
    );
    test(
      '$app proforma edits, cancels and validates conversion links after lost reply',
      () async {
        var server = ProformaChangeServer(app);
        var fx = await server.client();
        final snapshot = await fx.load();
        expect(fx.allowed('return'), isFalse);
        final line = snapshot.lines.single;
        await fx.send(
          InvoiceChangeCommand('amend', {
            ...server.body,
            'lines': [
              {
                'lineId': line['lineId'],
                'variantId': line['variantId'],
                'quantity': '2',
                'unitPrice': line['unitPrice'],
                'discountAmount': line['discountAmount'],
                'productPriceId': line['productPriceId'],
                'warehouseIds': line['warehouseIds'],
              },
            ],
          }),
        );
        await fx.refresh();
        expect((await fx.finish()).detail.summary.total, 200);
        server.finished = false;
        await fx.send(InvoiceChangeCommand('cancel', server.body));
        await fx.refresh();
        expect((await fx.finish()).detail.summary.status, 'CANCELLED');
        resetOnboardingStorage();
        server = ProformaChangeServer(app)..lost = true;
        fx = await server.client();
        await fx.load();
        final command = InvoiceChangeCommand('convert', {
          'invoiceId': invoiceOne,
          'expectedRevision': server.revision,
          'type': 'SALE',
          'deliveryStatus': 'PENDING',
        });
        await expectLater(fx.send(command), throwsA(anything));
        final resumed = InvoiceChangeFX(fx.context, server.row);
        await resumed.restore();
        await resumed.send(resumed.pending!);
        await resumed.refresh();
        server.brokenLink = true;
        await expectLater(resumed.finish(), throwsFormatException);
        expect(resumed.pending, isNotNull);
        server.brokenLink = false;
        expect((await resumed.finish()).detail.summary.status, 'CONVERTED');
        expect(server.mutationRequests.length, 2);
        expect(
          server.mutationRequests.first.body,
          server.mutationRequests.last.body,
        );
        expect(
          server.mutationRequests.first.headers['idempotency-key'],
          server.mutationRequests.last.headers['idempotency-key'],
        );
      },
    );
    test(
      '$app conversion refuses missing grants, expired source and stale revision',
      () async {
        final server = ProformaChangeServer(app);
        final fx = await server.client();
        await fx.load();
        final command = InvoiceChangeCommand('convert', {
          'invoiceId': invoiceOne,
          'expectedRevision': server.revision,
          'type': 'SALE',
          'deliveryStatus': 'PENDING',
        });
        server.write = false;
        await expectLater(
          fx.send(command),
          throwsA(isA<AuthError>().having((e) => e.code, 'code', 'FORBIDDEN')),
        );
        expect(server.mutationRequests, isEmpty);
        server.write = true;
        server.expired = true;
        await expectLater(
          fx.send(command),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'PROFORMA_EXPIRED'),
          ),
        );
        server.expired = false;
        server.conflict = true;
        await expectLater(
          fx.send(command),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'REVISION_CONFLICT'),
          ),
        );
      },
    );
    testWidgets('$app native proforma form and conversion confirmation', (
      tester,
    ) async {
      tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final create = ProformaCreateServer(app);
      await create.prepare();
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            home: Scaffold(
              body: SaleInvoiceProducts(appId: app, type: 'PROFORMA'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('proforma-valid-until')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('invoice-party-picker')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('sale-customer-${sale.customerId}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('افزودن کالا'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('پیراهن'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SHIRT-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تایید انتخاب شده‌ها'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ادامه'));
      await tester.pumpAndSettle();
      expect(find.text('تکمیل فاکتور'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('proforma-valid-until')),
        findsOneWidget,
      );
      expect(find.text('تسویه و پرداخت فاکتور'), findsNothing);
      expect(
        create.requests.any((r) => r.url.path.contains('/treasury')),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final server = ProformaChangeServer(app);
      await server.prepare();
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: InvoiceChangeScreen(appId: app, invoice: server.row),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تبدیل به فروش'));
      await tester.pumpAndSettle();
      if (app == 'mikyar') {
        await tester.tap(find.text('دریافت کامل'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('صندوق نمونه'));
        await tester.pumpAndSettle();
      }
      expect(find.text('مرجوعی'), findsNothing);
      final submit = find.text('ثبت تبدیل به فروش فاکتور');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(server.mutationRequests, isEmpty);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text('بله'));
      await tester.tap(find.text('بله'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(server.command!['deliveryStatus'], 'PENDING');
      expect(server.command!.containsKey('payments'), app == 'mikyar');
      if (app == 'mikyar') {
        final payment = (server.command!['payments'] as List).single;
        expect(payment['confirmed'], isTrue);
        expect(payment['amount'], 100);
        expect(payment['routing'], {'fundId': sale.cashFund});
      }
      expect(server.documentStatus, 'CONVERTED');
      expect(find.text('عملیات فاکتور با موفقیت تکمیل شد.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
