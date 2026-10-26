import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_pages/product/variant/controller.dart';

import '../../../mik_data/test/support/onboarding_fixtures.dart';
import '../../../mik_data/test/support/pim_fixtures.dart';

const secondOptionId = 'ffffffff-ffff-4fff-8fff-fffffffffff1';
const secondVariantId = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1';

class VariantServer {
  final String app;
  VariantServer(this.app);
  final store = MemoryPimStore();
  final requests = <http.Request>[];
  final permissions = [
    'pim.product.read',
    'pim.variant.read',
    'pim.variant.create',
    'pim.variant.update',
    'pim.variant.delete',
    'pim.attribute.read',
  ];
  final product = {
    ...fixturePim(PimResource.products),
    'variantAxes': [
      {
        'attributeId': attributeId,
        'valueIds': [optionId, secondOptionId],
      },
    ],
  };
  final rows = <Map<String, dynamic>>[
    {
      ...fixturePim(PimResource.variants),
      'combinationKey': '$attributeId:$optionId',
      'optionValues': [
        {'attributeId': attributeId, 'valueId': optionId},
      ],
    },
  ];
  bool unavailable = false, conflict = false, invalidPreview = false;
  final replies = <String, http.Response>{};
  List<http.Request> get mutations => requests
      .where((r) => r.method != 'GET' && !r.url.path.endsWith('/preview'))
      .toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      return jsonResponse(fixtureAuthorization(permissions));
    }
    if (path.endsWith('/products/$productId')) {
      return jsonResponse({'businessId': 12345678, 'item': product});
    }
    if (path.endsWith('/attributes/$attributeId')) {
      return jsonResponse({
        'businessId': 12345678,
        'item': {
          ...fixturePim(PimResource.attributes),
          'values': [
            {'valueId': optionId, 'name': 'قرمز', 'active': true},
            {'valueId': secondOptionId, 'name': 'آبی', 'active': true},
          ],
        },
      });
    }
    if (request.method == 'GET' && path.endsWith('/variants')) {
      return jsonResponse(fixturePimPage(PimResource.variants, items: rows));
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (path.endsWith('/preview')) {
      final axes = body['axes'] as List;
      final values = axes.isEmpty
          ? <String>[]
          : List<String>.from(axes.single['valueIds']);
      return jsonResponse({
        'productId': productId,
        'combinations': invalidPreview
            ? []
            : axes.isEmpty
            ? [[]]
            : [
                for (final id in values)
                  [
                    {'attributeId': attributeId, 'valueId': id},
                  ],
              ],
      });
    }
    final key = request.headers['idempotency-key']!;
    if (replies.containsKey(key)) return replies[key]!;
    if (conflict) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    http.Response result;
    if (path.endsWith('/generate')) {
      final values = List<String>.from(
        (body['axes'] as List).single['valueIds'],
      );
      var count = 0;
      final items = <Map<String, dynamic>>[];
      for (final id in values) {
        final found = rows.where(
          (v) => (v['optionValues'] as List).single['valueId'] == id,
        );
        if (found.isNotEmpty) {
          items.add(found.first);
          continue;
        }
        final row = {
          ...fixturePim(PimResource.variants, id: secondVariantId),
          'combinationKey': '$attributeId:$id',
          'optionValues': [
            {'attributeId': attributeId, 'valueId': id},
          ],
        };
        rows.add(row);
        items.add(row);
        count++;
      }
      result = jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'items': items,
        'createdCount': count,
      });
    } else {
      final index = rows.indexWhere(
        (v) => v['variantId'] == request.url.pathSegments.last,
      );
      rows[index] = {
        ...rows[index],
        'status': body['status'],
        'revision': (rows[index]['revision'] as int) + 1,
      };
      result = jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'item': rows[index],
      });
    }
    replies[key] = result;
    if (unavailable) {
      return jsonResponse({
        'error': {'code': 'UNAVAILABLE', 'retryable': true},
      }, 503);
    }
    return result;
  }

  ProductVariantController controller() => ProductVariantController(
    pimFixture(MockClient(respond), appId: app, store: store),
    productId,
  );
}
