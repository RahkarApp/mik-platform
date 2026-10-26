import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/detail/controller.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_detail_fixtures.dart';

void main() {
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    ProductDetailController controller({int business = 12345678}) =>
        ProductDetailController(
          appId: app,
          businessId: business,
          productId: productId,
        );
    test(
      '$app reloads the server product, all variants and authorized option names',
      () async {
        final server = DetailServer(app)..permissions.add('pim.attribute.read');
        server.activate();
        final c = controller();
        await c.load();
        expect(c.error.value, isNull);
        expect(c.product.value?.description, 'توضیح واقعی سرور');
        expect(c.variants.map((v) => v.status), ['ACTIVE', 'ARCHIVED']);
        expect(c.option(attributeId, optionId), 'قرمز');
        expect(server.requests.map((r) => r.method), everyElement('GET'));
        expect(
          server.requests.map((r) => r.headers['x-app-id']),
          everyElement(app),
        );
        final variants = server.requests.singleWhere(
          (r) => r.url.path.endsWith('/variants'),
        );
        expect(variants.url.queryParameters, {
          'productId': productId,
          'limit': '100',
        });
        c.onClose();
      },
    );
    test(
      '$app product permission is independent from variant and owner status',
      () async {
        final server = DetailServer(app)..permissions = ['pim.variant.read'];
        server.activate();
        final c = controller();
        await c.load();
        expect(c.product.value, isNull);
        expect(c.error.value, isNotEmpty);
        expect(server.requests, hasLength(1));
        c.onClose();
      },
    );
    test(
      '$app missing variant permission preserves only authorized product facts',
      () async {
        final server = DetailServer(app)..permissions = ['pim.product.read'];
        server.activate();
        final c = controller();
        await c.load();
        expect(c.product.value, isNotNull);
        expect(c.variants, isEmpty);
        expect(c.variantsError.value, contains('اجازه'));
        expect(server.requests, hasLength(2));
        c.onClose();
      },
    );
    test(
      '$app missing product is an error instead of a stale list snapshot',
      () async {
        final server = DetailServer(app)..productError = 'RECORD_NOT_FOUND';
        server.activate();
        final c = controller();
        await c.load();
        expect(c.product.value, isNull);
        expect(c.error.value, contains('وجود ندارد'));
        c.onClose();
      },
    );
    test('$app variant failure remains explicit and can be retried', () async {
      final server = DetailServer(app)..variantError = 'RPC_TIMEOUT';
      server.activate();
      final c = controller();
      await c.load();
      expect(c.product.value, isNotNull);
      expect(c.variantsError.value, isNotEmpty);
      expect(c.variants, isEmpty);
      server.variantError = null;
      await c.load();
      expect(c.variantsError.value, isNull);
      expect(c.variants, hasLength(2));
      c.onClose();
    });
    test('$app cross-product variants never enter details', () async {
      final server = DetailServer(app)..wrongParent = true;
      server.activate();
      final c = controller();
      await c.load();
      expect(c.variants, isEmpty);
      expect(c.variantsError.value, isNotEmpty);
      c.onClose();
    });
    test('$app mismatched route business makes no request', () async {
      final server = DetailServer(app)..activate();
      final c = controller(business: 87654321);
      await c.load();
      expect(c.product.value, isNull);
      expect(server.requests, isEmpty);
      c.onClose();
    });
    test(
      '$app late product and retries cannot switch to another session',
      () async {
        final server = DetailServer(app)
          ..pendingProduct = Completer<http.Response>();
        server.activate();
        final c = controller();
        final loading = c.load();
        while (!server.requests.any(
          (r) => r.url.path.endsWith('/products/$productId'),
        )) {
          await Future<void>.delayed(Duration.zero);
        }
        server.activate();
        server.pendingProduct!.complete(
          jsonResponse({'businessId': 12345678, 'item': server.product}),
        );
        await loading;
        expect(c.product.value, isNull);
        final count = server.requests.length;
        await c.load();
        expect(c.product.value, isNull);
        expect(server.requests, hasLength(count));
        c.onClose();
      },
    );
  }
}
