import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:mik_pages/invoice/read_controller.dart';
import 'package:mik_pages/product/screen/tabs/controllers/product.dart';

import '../../mik_data/test/realtime_test.dart' show SocketServer, until;
import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'invoice_read_test.dart' show InvoiceReadServer;
import 'product_list_controller_test.dart' show productPage, nextProduct;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app realtime reads preserve product filters, invoice type and loaded pages',
      () async {
        var products = 0;
        var holdNextRead = false;
        Completer<http.Response>? lateProduct;
        final invoices = InvoiceReadServer(app);
        final requests = <http.Request>[];
        final context = pimFixture(
          MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/branches')) {
              return jsonResponse({
                'items': [fixtureResult()['branch']],
                'nextCursor': null,
              });
            }
            if (request.url.path.endsWith('/authorization')) {
              final business =
                  request.url.queryParameters['scopeType'] == 'BUSINESS';
              return jsonResponse({
                ...fixtureAuthorization([
                  'pim.product.read',
                  'accounting.sale.read',
                  'accounting.purchase.read',
                ]),
                'scopeType': business ? 'BUSINESS' : 'BRANCH',
                'scopeId': business ? '12345678' : branch,
              });
            }
            if (request.url.path.endsWith('/pim/products')) {
              products++;
              if (holdNextRead) {
                holdNextRead = false;
                lateProduct = Completer<http.Response>();
                return lateProduct!.future;
              }
              return request.url.queryParameters['after'] == null
                  ? productPage(next: productId)
                  : productPage(id: nextProduct, name: 'کیف');
            }
            return invoices.respond(request);
          }),
          appId: app,
        ).context;
        await context.selectBranch((await context.branches()).single);
        final server = SocketServer();
        await server.open();
        final client = RealtimeFX.forContext(context, connect: server.connect);
        final product = ProductTabDashboardController();
        final invoice = InvoiceReadController(appId: app);
        addTearDown(() async {
          product.onClose();
          invoice.onClose();
          client.stop();
          await server.close();
        });
        await product.attach(app);
        await product.loadMore();
        invoice.type.value = 'PURCHASE';
        invoice.status.value = 'CANCELLED';
        await invoice.load();
        expect(invoice.error.value, isNull);
        expect(product.prd.length, 2);
        expect(products, 2);
        await client.start();
        await until(() => server.auths.isNotEmpty);
        final loadingChanges = <bool>[];
        final productLoading = product.loading.listen(loadingChanges.add);
        final invoiceLoading = invoice.loading.listen(loadingChanges.add);
        holdNextRead = true;
        server.changes(1, resource: 'pim.price');
        server.changes(2, resource: 'accounting.payment');
        await until(() => lateProduct != null);
        expect(product.loading.value, isFalse);
        expect(product.prd.length, 2);
        expect(invoice.loading.value, isFalse);
        expect(invoice.rows, isNotEmpty);
        lateProduct!.complete(productPage(next: productId));
        await until(
          () =>
              products == 4 &&
              !product.loading.value &&
              invoices.requests
                      .where((r) => r.url.path.endsWith('/invoices'))
                      .length >=
                  2,
        );
        expect(loadingChanges, isNot(contains(true)));
        await productLoading.cancel();
        await invoiceLoading.cancel();
        expect(product.prd.length, 2);
        expect(product.typeFilter.value, 'فعال');
        expect(invoice.type.value, 'PURCHASE');
        expect(invoice.status.value, 'CANCELLED');
        expect(invoice.rows.first.status, 'CANCELLED');
        expect(requests.every((r) => r.method == 'GET'), isTrue);
        expect(server.acks.map((a) => a['type']), everyElement('ack'));
        expect(server.auths.single.keys, isNot(contains('refreshToken')));
        // A reply started before access changed must not repopulate the authorized snapshot.
        lateProduct = null;
        holdNextRead = true;
        final previousRead = product.init();
        await until(() => lateProduct != null);
        await server.resync(2, reason: 'ACCESS_CHANGED');
        await until(
          () =>
              server.auths.length == 2 &&
              !product.loading.value &&
              product.prd.isNotEmpty,
        );
        lateProduct!.complete(productPage(name: 'قدیمی'));
        await previousRead;
        expect(product.prd.any((r) => r.name == 'قدیمی'), isFalse);
        expect(invoice.type.value, 'PURCHASE');
        expect(invoice.status.value, 'CANCELLED');
      },
    );
  }
}
