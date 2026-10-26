import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_pages/product/price/controller.dart';

import '../../../mik_data/test/support/onboarding_fixtures.dart';
import '../../../mik_data/test/support/pim_fixtures.dart';

const newPriceId = 'dddddddd-dddd-4ddd-8ddd-ddddddddddde';
const priceOverrideId = '11111111-1111-4111-8111-111111111118';

class PriceServer {
  final String app;
  PriceServer(this.app);
  final commands = MemoryPimStore();
  final requests = <http.Request>[];
  final permissions = [
    'pim.product.read',
    'pim.variant.read',
    'pim.price.read',
    'pim.price.create',
    'pim.price.update',
    'pim.price.default.update',
  ];
  final prices = <Map<String, dynamic>>[
    {...fixturePim(PimResource.prices), 'amount': 100},
  ];
  final overrides = <Map<String, dynamic>>[];
  bool unavailable = false, revisionConflict = false, withVariants = false;
  final replies = <String, http.Response>{};
  List<http.Request> get mutations =>
      requests.where((r) => r.method != 'GET').toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      return jsonResponse(
        fixtureAuthorization([
          ...permissions,
          if (withVariants) ...[
            'pim.attribute.read',
            'pim.product.category.read',
          ],
        ]),
      );
    }
    if (path.endsWith('/products/$productId')) {
      return jsonResponse({
        'businessId': 12345678,
        'item': {
          ...fixturePim(PimResource.products),
          if (withVariants)
            'variantAxes': [
              {
                'attributeId': attributeId,
                'valueIds': [optionId],
              },
            ],
        },
      });
    }
    if (path.endsWith('/variants')) {
      return jsonResponse(
        fixturePimPage(
          PimResource.variants,
          items: [
            {
              ...fixturePim(PimResource.variants),
              if (withVariants)
                'optionValues': [
                  {'attributeId': attributeId, 'valueId': optionId},
                ],
            },
          ],
        ),
      );
    }
    for (final resource in [PimResource.attributes, PimResource.categories]) {
      if (path.endsWith('/${resource.path}'))
        return jsonResponse(fixturePimPage(resource));
    }
    if (path.endsWith('/price')) {
      return jsonResponse({
        'businessId': 12345678,
        'productId': productId,
        'variantId': variantId,
        'productPriceId': request.url.queryParameters['productPriceId'],
        'amount': prices.firstWhere(
          (p) =>
              p['productPriceId'] ==
              request.url.queryParameters['productPriceId'],
        )['amount'],
        'currency': 'TOMAN',
        'source': 'PRODUCT_BASE',
      });
    }
    final isOverride = path.contains('/price-overrides');
    if (request.method == 'GET') {
      return jsonResponse(
        fixturePimPage(
          isOverride ? PimResource.overrides : PimResource.prices,
          items: isOverride
              ? overrides
                    .where(
                      (v) =>
                          v['productPriceId'] ==
                          request.url.queryParameters['productPriceId'],
                    )
                    .toList()
              : prices,
        ),
      );
    }
    final key = request.headers['idempotency-key']!;
    if (replies.containsKey(key)) return replies[key]!;
    if (revisionConflict) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    final data = Map<String, dynamic>.from(jsonDecode(request.body));
    final rows = isOverride ? overrides : prices;
    final idKey = isOverride ? 'overrideId' : 'productPriceId';
    final resource = isOverride ? PimResource.overrides : PimResource.prices;
    final index = request.method == 'PATCH'
        ? rows.indexWhere((v) => v[idKey] == request.url.pathSegments.last)
        : -1;
    final previous = index < 0
        ? {
            ...fixturePim(
              resource,
              id: isOverride ? priceOverrideId : newPriceId,
            ),
            if (!isOverride) 'isDefault': false,
          }
        : rows[index];
    data.remove('expectedRevision');
    final result = {
      ...previous,
      ...data,
      'revision': (previous['revision'] as int) + 1,
    };
    if (!isOverride && result['isDefault'] == true) {
      for (final row in rows) {
        if (row[idKey] != result[idKey] && row['isDefault'] == true) {
          row['isDefault'] = false;
          row['revision'] = (row['revision'] as int) + 1;
        }
      }
    }
    if (index < 0) {
      rows.add(result);
    } else {
      rows[index] = result;
    }
    final response = jsonResponse({
      'businessId': 12345678,
      'replayed': false,
      'item': result,
    });
    replies[key] = response;
    if (unavailable) {
      return jsonResponse({
        'error': {'code': 'UNAVAILABLE', 'retryable': true},
      }, 503);
    }
    return response;
  }

  ProductPriceController controller() => ProductPriceController(
    pimFixture(MockClient(respond), appId: app, store: commands),
    productId,
  );
}
