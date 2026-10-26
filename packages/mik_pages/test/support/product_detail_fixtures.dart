import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';

import '../../../mik_data/test/support/onboarding_fixtures.dart';
import '../../../mik_data/test/support/pim_fixtures.dart';

class DetailServer {
  final String app;
  DetailServer(this.app);
  final requests = <http.Request>[];
  List<String> permissions = ['pim.product.read', 'pim.variant.read'];
  String? productError, variantError;
  bool wrongParent = false;
  Completer<http.Response>? pendingProduct;
  Map<String, dynamic> get product => {
    ...fixturePim(PimResource.products),
    'description': 'توضیح واقعی سرور',
    'model': 'M-10',
  };
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      return jsonResponse(fixtureAuthorization(permissions));
    }
    if (path.endsWith('/products/$productId')) {
      if (pendingProduct != null) return pendingProduct!.future;
      if (productError != null) {
        return jsonResponse({
          'error': {'code': productError},
        }, 404);
      }
      return jsonResponse({'businessId': 12345678, 'item': product});
    }
    if (path.endsWith('/products')) {
      return jsonResponse(fixturePimPage(PimResource.products));
    }
    if (path.endsWith('/variants')) {
      if (variantError != null) {
        return jsonResponse({
          'error': {'code': variantError},
        }, 503);
      }
      return jsonResponse(
        fixturePimPage(
          PimResource.variants,
          items: [
            {
              ...fixturePim(PimResource.variants),
              'productId': wrongParent ? categoryId : productId,
              'barcodes': ['1234567890'],
              'optionValues': [
                {'attributeId': attributeId, 'valueId': optionId},
              ],
            },
            if (request.url.queryParameters['status'] == null)
              fixturePim(
                PimResource.variants,
                id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccd',
                status: 'ARCHIVED',
              ),
          ],
        ),
      );
    }
    if (path.endsWith('/attributes/$attributeId')) {
      return jsonResponse({
        'businessId': 12345678,
        'item': fixturePim(PimResource.attributes),
      });
    }
    throw StateError('Unexpected route: $path');
  }

  PimFX activate() => pimFixture(MockClient(respond), appId: app);
}
