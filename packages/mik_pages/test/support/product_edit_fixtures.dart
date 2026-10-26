import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_pages/product/edit/controller.dart';

import '../../../mik_data/test/support/onboarding_fixtures.dart';
import '../../../mik_data/test/support/pim_fixtures.dart';

class EditServer {
  final String app;
  EditServer(this.app);
  final commands = MemoryPimStore();
  final requests = <http.Request>[];
  final categoryRows = [fixturePim(PimResource.categories)];
  final permissions = [
    'pim.product.read',
    'pim.product.update',
    'pim.variant.read',
    'pim.variant.update',
  ];
  Map<String, dynamic> product = {
    ...fixturePim(PimResource.products),
    'model': 'M-10',
    'description': 'متن موجود',
    'revision': 9,
  };
  Map<String, dynamic> variant = {
    ...fixturePim(PimResource.variants),
    'revision': 7,
  };
  bool loseResponse = false, conflict = false;
  Completer<http.Response>? pendingPatch;
  final results = <String, http.Response>{};
  List<http.Request> get patches =>
      requests.where((r) => r.method == 'PATCH').toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      return jsonResponse(fixtureAuthorization(permissions));
    }
    if (path == '/v1/catalog/products') return jsonResponse(fixtureCatalog());
    if (path.endsWith('/categories')) {
      return jsonResponse(
        fixturePimPage(PimResource.categories, items: categoryRows),
      );
    }
    if (path.endsWith('/products')) {
      return jsonResponse(
        fixturePimPage(PimResource.products, items: [product]),
      );
    }
    if (path.endsWith('/variants')) {
      return jsonResponse(
        fixturePimPage(PimResource.variants, items: [variant]),
      );
    }
    final isVariant = path.endsWith('/variants/$variantId');
    if (!isVariant && !path.endsWith('/products/$productId')) {
      throw StateError('Unexpected route: $path');
    }
    if (request.method == 'GET') {
      return jsonResponse({
        'businessId': 12345678,
        'item': isVariant ? variant : product,
      });
    }
    if (request.method != 'PATCH') throw StateError('Unexpected mutation');
    if (pendingPatch != null) return pendingPatch!.future;
    final key = request.headers['idempotency-key']!;
    if (results.containsKey(key)) return results[key]!;
    final before = isVariant ? variant : product;
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (conflict || body['expectedRevision'] != before['revision']) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    body.remove('expectedRevision');
    final updated = {
      ...before,
      ...body,
      'revision': (before['revision'] as int) + 1,
    };
    if (isVariant) {
      variant = updated;
    } else {
      product = updated;
    }
    final result = jsonResponse({
      'businessId': 12345678,
      'replayed': false,
      'item': updated,
    });
    results[key] = result;
    if (loseResponse) {
      return jsonResponse({
        'error': {'code': 'UNAVAILABLE', 'retryable': true},
      }, 503);
    }
    return result;
  }

  PimFX activate() =>
      pimFixture(MockClient(respond), appId: app, store: commands);
  ProductEditController controller({bool forVariant = false}) =>
      ProductEditController(
        activate(),
        productId: productId,
        variantId: forVariant ? variantId : null,
      );
}
