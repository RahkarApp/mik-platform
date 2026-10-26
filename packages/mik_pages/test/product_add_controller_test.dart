import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/utils/fx/business_context.dart';

import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_add_fixtures.dart';

void main() {
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app creates product then default zero price then activates using server revision',
      () async {
        final server = AddServer(app);
        final c = await server.ready();
        expect(c.loadError.value, isNull);
        expect(await c.save(name: 'پیراهن', price: '۰'), isTrue);
        expect(server.mutations.map((r) => r.method), [
          'POST',
          'POST',
          'PATCH',
        ]);
        expect(jsonDecode(server.mutations.first.body), {
          'name': 'پیراهن',
          'status': 'DRAFT',
          'categoryIds': [categoryId],
          'primaryCategoryId': categoryId,
          'unitId': 1,
        });
        expect(jsonDecode(server.mutations[1].body), {
          'productId': productId,
          'name': 'فروش',
          'amount': 0,
          'isDefault': true,
        });
        expect(jsonDecode(server.mutations.last.body), {
          'status': 'ACTIVE',
          'expectedRevision': 3,
        });
        expect(
          server.mutations.map((r) => r.headers['idempotency-key']).toSet(),
          hasLength(3),
        );
        expect(
          server.requests.map((r) => r.headers['x-app-id']),
          everyElement(app),
        );
      },
    );
    test(
      '$app blank price creates a draft without invented zero or activation',
      () async {
        final server = AddServer(app);
        final c = await server.ready();
        expect(await c.save(name: 'پیراهن'), isTrue);
        expect(server.mutations, hasLength(1));
        expect(jsonDecode(server.mutations.single.body)['status'], 'DRAFT');
      },
    );
    test(
      '$app selected axes generate variants before price and activation',
      () async {
        final server = AddServer(app);
        final c = await server.ready();
        c.option(attributeId, optionId, true);
        expect(await c.save(name: 'پیراهن', price: '120'), isTrue);
        expect(server.mutations.map((r) => r.url.pathSegments.last), [
          'products',
          'generate',
          'prices',
          productId,
        ]);
        expect(jsonDecode(server.mutations.first.body)['variantAxes'], [
          {
            'attributeId': attributeId,
            'valueIds': [optionId],
          },
        ]);
        expect(jsonDecode(server.mutations[1].body), {'productId': productId});
      },
    );
    test(
      '$app barcode belongs to the server-created base variant only',
      () async {
        final server = AddServer(app);
        final c = await server.ready();
        expect(await c.save(name: 'پیراهن', barcode: '123'), isTrue);
        expect(server.mutations, hasLength(2));
        expect(jsonDecode(server.mutations.last.body), {
          'barcodes': ['123'],
          'expectedRevision': 3,
        });
      },
    );
    test(
      '$app failed price retries its original key without recreating a product',
      () async {
        final server = AddServer(app)..failPrice = true;
        final c = await server.ready();
        expect(await c.save(name: 'پیراهن', price: '10'), isFalse);
        expect(c.locked.value, isTrue);
        final key = server.mutations.last.headers['idempotency-key'];
        server.failPrice = false;
        final reopened = server.controller();
        await reopened.load();
        expect(reopened.locked.value, isTrue);
        expect(
          await reopened.save(name: 'نباید ثبت شود', price: '999'),
          isTrue,
        );
        expect(
          server.mutations.where((r) => r.url.path.endsWith('/products')),
          hasLength(1),
        );
        expect(server.mutations[2].headers['idempotency-key'], key);
        expect(jsonDecode(server.mutations[2].body)['amount'], 10);
      },
    );
    test(
      '$app missing price grants and invalid inputs send no mutation',
      () async {
        final server = AddServer(app)
          ..permissions.remove('pim.price.default.update');
        final c = await server.ready();
        expect(await c.save(name: 'پیراهن', price: '0'), isFalse);
        expect(await c.save(name: ''), isFalse);
        c.unitId.value = 0;
        expect(await c.save(name: 'پیراهن'), isFalse);
        expect(server.mutations, isEmpty);
      },
    );
    test(
      '$app invalid decimal, over-limit price and barcode with axes fail before writes',
      () async {
        final server = AddServer(app);
        final c = await server.ready();
        for (final price in ['-1', '1.5', '9000000000001', 'text']) {
          expect(await c.save(name: 'پیراهن', price: price), isFalse);
        }
        c.option(attributeId, optionId, true);
        expect(await c.save(name: 'پیراهن', barcode: '123'), isFalse);
        expect(server.mutations, isEmpty);
      },
    );
    test('$app double submission sends only one product request', () async {
      final server = AddServer(app)
        ..pendingProduct = Completer<http.Response>();
      final c = await server.ready();
      final first = c.save(name: 'پیراهن');
      expect(await c.save(name: 'دیگری'), isFalse);
      while (server.mutations.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      server.pendingProduct!.complete(server.created(server.mutations.single));
      expect(await first, isTrue);
      expect(server.mutations, hasLength(1));
    });
    test(
      '$app switched context prevents submitting a form from the old session',
      () async {
        final server = AddServer(app);
        final c = await server.ready();
        BusinessContext.clear(app);
        expect(await c.save(name: 'پیراهن'), isFalse);
        expect(server.mutations, isEmpty);
      },
    );
  }
}
