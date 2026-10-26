import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_pages/product/variant/axes_controller.dart';

import '../../../mik_data/test/support/onboarding_fixtures.dart';
import '../../../mik_data/test/support/pim_fixtures.dart';
import 'product_variant_fixtures.dart';

const sizeAttributeId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1';
const sizeOptionId = 'ffffffff-ffff-4fff-8fff-fffffffffff2';

class AxesServer extends VariantServer {
  AxesServer(super.app) {
    permissions.addAll([
      'pim.product.update',
      'pim.attribute.assign',
      'pim.attribute.update',
    ]);
    product['variantAxes'] = [
      {
        'attributeId': attributeId,
        'valueIds': [optionId],
      },
    ];
  }
  final catalog = <Map<String, dynamic>>[
    {
      ...fixturePim(PimResource.attributes),
      'values': [
        {
          'valueId': optionId,
          'name': 'قرمز',
          'code': 'RED',
          'colorHex': '#FF0000',
          'active': true,
        },
        {
          'valueId': secondOptionId,
          'name': 'آبی',
          'colorHex': '#0000FF',
          'active': true,
        },
      ],
    },
    {
      ...fixturePim(PimResource.attributes, id: sizeAttributeId, name: 'سایز'),
      'kind': 'SIZE',
      'values': [
        {'valueId': sizeOptionId, 'name': 'بزرگ', 'active': true},
      ],
    },
  ];
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/convert-to-variable')) {
      requests.add(request);
      final key = request.headers['idempotency-key']!;
      if (replies.containsKey(key)) return replies[key]!;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (conflict)
        return jsonResponse({
          'error': {'code': 'REVISION_CONFLICT'},
        }, 409);
      product['variantAxes'] = body['variantAxes'];
      product['revision'] = (product['revision'] as int) + 1;
      rows.single['optionValues'] = body['optionValues'];
      rows.single['combinationKey'] = (body['optionValues'] as List)
          .map((pair) => '${pair['attributeId']}:${pair['valueId']}')
          .join('|');
      rows.single['revision'] = (rows.single['revision'] as int) + 1;
      final response = jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'product': product,
        'variant': rows.single,
      });
      replies[key] = response;
      if (unavailable)
        return jsonResponse({
          'error': {'code': 'UNAVAILABLE', 'retryable': true},
        }, 503);
      return response;
    }
    if (request.method == 'GET' && path.endsWith('/attributes')) {
      requests.add(request);
      return jsonResponse(
        fixturePimPage(
          PimResource.attributes,
          items: catalog.where((a) => a['status'] == 'ACTIVE').toList(),
        ),
      );
    }
    final attr = catalog
        .where((a) => path.endsWith('/attributes/${a['attributeId']}'))
        .firstOrNull;
    if (attr != null && request.method == 'GET') {
      requests.add(request);
      return jsonResponse({'businessId': 12345678, 'item': attr});
    }
    if (request.method != 'PATCH' ||
        attr == null && !path.endsWith('/products/$productId')) {
      return super.respond(request);
    }
    requests.add(request);
    final key = request.headers['idempotency-key']!;
    if (replies.containsKey(key)) return replies[key]!;
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final row = attr ?? product;
    if (conflict || body['expectedRevision'] != row['revision']) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    final patch = Map<String, dynamic>.from(body)..remove('expectedRevision');
    row.addAll(patch);
    row['revision'] = (row['revision'] as int) + 1;
    final result = jsonResponse({
      'businessId': 12345678,
      'replayed': false,
      'item': row,
    });
    replies[key] = result;
    if (unavailable) {
      return jsonResponse({
        'error': {'code': 'UNAVAILABLE', 'retryable': true},
      }, 503);
    }
    return result;
  }

  ProductAxesController axesController() => ProductAxesController(
    pimFixture(MockClient(respond), appId: app, store: store),
    productId,
  );
}
