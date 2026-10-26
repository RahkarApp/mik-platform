import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/source/remote/pim_group_store.dart';
import 'package:mik_data/utils/fx/pim_group.dart';
import 'package:mik_pages/product/add/controller.dart';

import '../../../mik_data/test/support/onboarding_fixtures.dart';
import '../../../mik_data/test/support/pim_fixtures.dart';

class AddGroupStore implements PimGroupStore {
  final values = <String, PimGroupState>{};
  @override
  Future<PimGroupState> read(String key) async =>
      values[key] ?? const PimGroupState();
  @override
  Future<void> write(String key, PimGroupState state) async {
    values[key] = PimGroupState.fromJson(
      jsonDecode(jsonEncode(state.toJson())),
    );
  }
}

class AddServer {
  final String app;
  AddServer(this.app);
  final requests = <http.Request>[];
  final store = AddGroupStore();
  final commands = MemoryPimStore();
  final permissions = <String>[
    'pim.product.read',
    'pim.product.create',
    'pim.product.update',
    'pim.product.category.read',
    'pim.attribute.read',
    'pim.attribute.assign',
    'pim.variant.create',
    'pim.variant.read',
    'pim.variant.update',
    'pim.price.create',
    'pim.price.default.update',
  ];
  bool failPrice = false;
  Completer<http.Response>? pendingProduct;
  List<http.Request> get mutations =>
      requests.where((r) => r.method != 'GET').toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      return jsonResponse(fixtureAuthorization(permissions));
    }
    if (path == '/v1/catalog/products') return jsonResponse(fixtureCatalog());
    if (request.method == 'GET') {
      if (path.endsWith('/products')) {
        return jsonResponse(fixturePimPage(PimResource.products));
      }
      if (path.endsWith('/variants')) {
        return jsonResponse(fixturePimPage(PimResource.variants));
      }
      final resource = path.endsWith('/categories')
          ? PimResource.categories
          : PimResource.attributes;
      return jsonResponse(fixturePimPage(resource));
    }
    if (path.endsWith('/products')) {
      if (pendingProduct != null) return pendingProduct!.future;
      return created(request);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (path.endsWith('/variants/generate')) {
      return jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'items': [fixturePim(PimResource.variants)],
        'createdCount': 1,
      });
    }
    if (path.endsWith('/prices')) {
      if (failPrice) {
        return jsonResponse({
          'error': {'code': 'UNAVAILABLE', 'retryable': true},
        }, 503);
      }
      return jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'item': {...fixturePim(PimResource.prices), ...body},
      });
    }
    final variant = path.contains('/variants/');
    return jsonResponse({
      'businessId': 12345678,
      'replayed': false,
      'item': {
        ...fixturePim(variant ? PimResource.variants : PimResource.products),
        ...body,
        'revision': 4,
      },
    });
  }

  http.Response created(http.Request request) => jsonResponse({
    'businessId': 12345678,
    'replayed': false,
    'item': {
      ...fixturePim(PimResource.products, status: 'DRAFT'),
      ...jsonDecode(request.body) as Map<String, dynamic>,
    },
    'baseVariant': fixturePim(PimResource.variants),
  });
  PimProductAddController controller() {
    final fx = pimFixture(MockClient(respond), appId: app, store: commands);
    return PimProductAddController(PimGroupFX(fx, store: store));
  }

  Future<PimProductAddController> ready() async {
    final c = controller();
    await c.load();
    c.category(categoryId, true);
    c.unitId.value = 1;
    return c;
  }
}
