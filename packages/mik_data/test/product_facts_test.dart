import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/source/remote/models/inventory_quantity.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/product_facts.dart';

import 'support/onboarding_fixtures.dart';
import 'support/pim_fixtures.dart';

const secondVariant = 'cccccccc-cccc-4ccc-8ccc-cccccccccccd';
const secondPrice = 'dddddddd-dddd-4ddd-8ddd-ddddddddddde';

class FactsServer {
  final String app;
  FactsServer(this.app);
  final requests = <http.Request>[];
  List<String> variants = [variantId, secondVariant];
  List<String> titles = [priceId, secondPrice];
  List<String> permissions = ['pim.variant.read', 'pim.price.read'];
  bool stockAllowed = true, blocked = false, wrongProduct = false;
  String? priceError, stockError;
  final quantities = <String, String>{variantId: '0.1', secondVariant: '0.2'};
  Completer<http.Response>? pendingStock;
  Map<String, Object?> availability(List<String> ids) => {
    'businessId': 12345678,
    'fulfillmentMode': 'SINGLE_WAREHOUSE',
    'items': [
      for (final id in ids)
        {
          'variantId': id,
          'productId': wrongProduct ? secondPrice : productId,
          'unitId': 1,
          'active': true,
          'available': blocked ? '0' : quantities[id] ?? '1',
          'warehouses': [
            {
              'warehouseId': warehouse,
              'available': blocked ? '0' : quantities[id] ?? '1',
              'revision': 0,
              'blockedForCount': blocked,
            },
          ],
        },
    ],
  };
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final scope = request.url.queryParameters['scopeType'];
      return jsonResponse({
        ...fixtureAuthorization(
          scope == 'BRANCH'
              ? (stockAllowed ? ['inventory.stock.read'] : [])
              : permissions,
        ),
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
    if (path.endsWith('/variants')) {
      return jsonResponse(
        fixturePimPage(
          PimResource.variants,
          items: [
            for (final id in variants) fixturePim(PimResource.variants, id: id),
          ],
        ),
      );
    }
    if (path.endsWith('/prices')) {
      return jsonResponse(
        fixturePimPage(
          PimResource.prices,
          items: [
            for (final id in titles) fixturePim(PimResource.prices, id: id),
          ],
        ),
      );
    }
    if (path.endsWith('/price')) {
      final title = request.url.queryParameters['productPriceId'];
      if (title == secondPrice && priceError != null) {
        return jsonResponse({
          'error': {'code': priceError},
        }, 422);
      }
      final variant = request.url.pathSegments[5];
      return jsonResponse({
        'businessId': 12345678,
        'productId': productId,
        'variantId': variant,
        'productPriceId': title,
        'amount': title == priceId ? 0 : (variant == variantId ? 100 : 120),
        'currency': 'TOMAN',
        'source': title == priceId ? 'PRODUCT_BASE' : 'VARIANT_OVERRIDE',
      });
    }
    if (path.endsWith('/availability')) {
      if (pendingStock != null) return pendingStock!.future;
      if (stockError != null) {
        return jsonResponse({
          'error': {'code': stockError},
        }, 422);
      }
      return jsonResponse(
        availability(List<String>.from(jsonDecode(request.body)['variantIds'])),
      );
    }
    throw StateError('Unexpected route: $path');
  }

  Future<PimFX> prepare() async {
    final fx = pimFixture(MockClient(respond), appId: app);
    await fx.authorize();
    await fx.context.selectBranch((await fx.context.branches()).single);
    requests.clear();
    return fx;
  }
}

PimProduct product() => PimProduct.fromJson(fixturePim(PimResource.products));

void main() {
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  test(
    'quantities preserve six decimals and exact sums including server maximum',
    () {
      expect(
        (InventoryQuantity.fromJson('0.1') + InventoryQuantity.fromJson('0.2'))
            .toString(),
        '0.3',
      );
      expect(
        InventoryQuantity.fromJson('9007199254.740991').toString(),
        '9007199254.740991',
      );
      expect(InventoryQuantity.fromJson('0.000001').toString(), '0.000001');
      expect(InventoryQuantity.fromJson('0.000000').isZero, isTrue);
      for (final invalid in [
        null,
        0,
        0.1,
        '-1',
        '1e2',
        '01',
        '1.0000001',
        '9007199254.740992',
      ]) {
        expect(
          () => InventoryQuantity.fromJson(invalid),
          throwsFormatException,
        );
      }
    },
  );
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app uses all titles, overrides and exact default-warehouse availability',
      () async {
        final server = FactsServer(app);
        final result = await ProductFactsFX(await server.prepare())
            .load(product());
        expect(result.price.minimum, 0);
        expect(result.price.maximum, 120);
        expect(result.stock.available.toString(), '0.3');
        expect(result.price.variants[variantId]?.minimum, 0);
        expect(result.price.variants[variantId]?.maximum, 100);
        expect(result.price.variants[secondVariant]?.maximum, 120);
        expect(result.stock.variants[variantId]?.available.toString(), '0.1');
        expect(
          result.stock.variants[secondVariant]?.warehouses.single.warehouseId,
          warehouse,
        );
        final stock = server.requests.singleWhere(
          (r) => r.url.path.endsWith('/availability'),
        );
        expect(stock.method, 'POST');
        expect(stock.headers['X-Branch-Id'], branch);
        expect(stock.headers['X-App-Id'], app);
        expect(jsonDecode(stock.body), {
          'variantIds': [variantId, secondVariant],
        });
        expect(
          server.requests.where((r) => r.url.path.endsWith('/price')),
          hasLength(4),
        );
      },
    );
    test(
      '$app skips only server-invalid titles, without substituting a default',
      () async {
        final server = FactsServer(app)..priceError = 'PRICE_UNAVAILABLE';
        final result = await ProductFactsFX(await server.prepare())
            .load(product());
        expect(result.price.minimum, 0);
        expect(result.price.maximum, 0);
        expect(result.stock.available.toString(), '0.3');
      },
    );
    test(
      '$app price failure never exposes a partial range or destroys valid stock',
      () async {
        final server = FactsServer(app)..priceError = 'INTERNAL_ERROR';
        final result = await ProductFactsFX(await server.prepare())
            .load(product());
        expect(result.price.minimum, isNull);
        expect(result.price.message, isNotEmpty);
        expect(result.stock.available.toString(), '0.3');
      },
    );
    test(
      '$app missing warehouse and malformed stock are unknown rather than zero',
      () async {
        final server = FactsServer(app)
          ..stockError = 'DEFAULT_WAREHOUSE_UNAVAILABLE';
        final fx = ProductFactsFX(await server.prepare());
        final unavailable = await fx.load(product());
        expect(unavailable.stock.available, isNull);
        expect(unavailable.stock.message, contains('انبار پیش‌فرض'));
        server.stockError = null;
        server.wrongProduct = true;
        expect((await fx.load(product())).stock.available, isNull);
      },
    );
    test(
      '$app counts server zero during stock count and explains blocking',
      () async {
        final server = FactsServer(app)..blocked = true;
        final result = await ProductFactsFX(await server.prepare())
            .load(product());
        expect(result.stock.available?.isZero, isTrue);
        expect(result.stock.blockedForCount, isTrue);
      },
    );
    test('$app missing grants make no unauthorized reads', () async {
      final server = FactsServer(app)
        ..permissions = ['pim.variant.read']
        ..stockAllowed = false;
      final result = await ProductFactsFX(await server.prepare())
          .load(product());
      expect(result.price.minimum, isNull);
      expect(result.stock.available, isNull);
      expect(server.requests.map((r) => r.url.pathSegments.last), ['variants']);
    });
    test('$app no active variants does not invent zero stock', () async {
      final server = FactsServer(app)..variants = [];
      final result = await ProductFactsFX(await server.prepare())
          .load(product());
      expect(result.stock.available, isNull);
      expect(result.price.minimum, isNull);
      expect(server.requests, hasLength(1));
    });
    test(
      '$app availability batches at thirty and sums all variant results',
      () async {
        final server = FactsServer(app)
          ..titles = []
          ..variants = List.generate(
            31,
            (i) => 'cccccccc-cccc-4ccc-8ccc-${i.toString().padLeft(12, '0')}',
          );
        final result = await ProductFactsFX(await server.prepare())
            .load(product());
        expect(result.stock.available.toString(), '31');
        final requests = server.requests.where(
          (r) => r.url.path.endsWith('/availability'),
        );
        expect(
          requests.map(
            (r) => (jsonDecode(r.body)['variantIds'] as List).length,
          ),
          [30, 1],
        );
        expect(result.price.minimum, isNull);
      },
    );
    test(
      '$app rejects late availability after selected context is cleared',
      () async {
        final server = FactsServer(app)
          ..pendingStock = Completer<http.Response>();
        final fx = await server.prepare();
        final loading = ProductFactsFX(fx).load(product());
        final assertion = expectLater(loading, throwsA(isA<AuthError>()));
        while (!server.requests.any(
          (r) => r.url.path.endsWith('/availability'),
        )) {
          await Future<void>.delayed(Duration.zero);
        }
        BusinessContext.clear(app);
        server.pendingStock!.complete(
          jsonResponse(server.availability(server.variants)),
        );
        await assertion;
      },
    );
  }
}
