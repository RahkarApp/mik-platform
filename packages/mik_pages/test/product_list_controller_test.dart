import 'package:get/get.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/screen/tabs/controllers/product.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const nextProduct = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaab';
http.Response productPage({
  String id = productId,
  String name = 'پیراهن',
  String? next,
}) => jsonResponse(
  fixturePimPage(
    PimResource.products,
    items: [fixturePim(PimResource.products, id: id, name: name)],
    next: next,
  ),
);
void bind(String app, Future<http.Response> Function(http.Request) response) {
  pimFixture(MockClient(response), appId: app);
}

Future<void> finishSearch(ProductTabDashboardController c) async {
  for (var i = 0; i < 100 && c.loading.value; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(c.loading.value, isFalse);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProductTabDashboardController c;
  setUp(() {
    c = ProductTabDashboardController();
  });
  tearDown(() {
    c.onClose();
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app reads server pages with app credentials and never sends speculative filters',
      () async {
        final requests = <http.Request>[];
        bind(app, (request) async {
          requests.add(request);
          if (request.url.path.endsWith('/authorization')) {
            return jsonResponse(fixtureAuthorization(['pim.product.read']));
          }
          return request.url.queryParameters['after'] == null
              ? productPage(next: productId)
              : productPage(id: nextProduct, name: 'کیف');
        });
        await c.attach(app);
        expect(c.prd.map((row) => row.id), [productId]);
        expect(c.hasMore.value, isTrue);
        await Future.wait([c.loadMore(), c.loadMore()]);
        expect(c.prd.map((row) => row.id), [productId, nextProduct]);
        expect(c.hasMore.value, isFalse);
        expect(requests, hasLength(3));
        expect(requests.last.url.path, '/v1/businesses/12345678/pim/products');
        expect(requests.last.url.queryParameters, {
          'limit': '100',
          'status': 'ACTIVE',
          'after': productId,
        });
        expect(requests.map((r) => r.headers['x-app-id']), everyElement(app));
        expect(
          requests.map((r) => r.headers['authorization']),
          everyElement('Bearer access'),
        );
      },
    );

    test(
      '$app debounces search and includes matches on unloaded pages',
      () async {
        final queries = <Map<String, String>>[];
        bind(app, (request) async {
          if (request.url.path.endsWith('/authorization')) {
            return jsonResponse(fixtureAuthorization(['pim.product.read']));
          }
          queries.add(request.url.queryParameters);
          return request.url.queryParameters['after'] == null
              ? productPage(next: productId)
              : productPage(id: nextProduct, name: 'کیف ۱۲');
        });
        await c.attach(app);
        c.search('پیراهن');
        c.search('کیف12');
        await finishSearch(c);
        expect(c.prd.single.name, 'کیف ۱۲');
        expect(queries, hasLength(3));
        expect(
          queries.any((q) => q.containsKey('search') || q.containsKey('q')),
          isFalse,
        );
      },
    );

    test('$app a late result cannot replace a newer search', () async {
      final oldResponse = Completer<http.Response>();
      final oldStarted = Completer<void>();
      var pages = 0;
      bind(app, (request) async {
        if (request.url.path.endsWith('/authorization')) {
          return jsonResponse(fixtureAuthorization(['pim.product.read']));
        }
        pages++;
        if (pages == 2) {
          oldStarted.complete();
          return oldResponse.future;
        }
        return productPage(name: pages == 1 ? 'اولیه' : 'جدید');
      });
      await c.attach(app);
      c.search('قدیمی');
      await oldStarted.future;
      c.search('جدید');
      await finishSearch(c);
      oldResponse.complete(productPage(name: 'قدیمی'));
      await Future<void>.delayed(Duration.zero);
      expect(c.prd.single.name, 'جدید');
      expect(c.error.value, isNull);
    });

    test(
      '$app status filtering uses real enums including all draft products',
      () async {
        final statuses = <String?>[];
        bind(app, (request) async {
          if (request.url.path.endsWith('/authorization')) {
            return jsonResponse(fixtureAuthorization(['pim.product.read']));
          }
          final status = request.url.queryParameters['status'];
          statuses.add(status);
          return jsonResponse(
            fixturePimPage(
              PimResource.products,
              items: [
                fixturePim(PimResource.products, status: status ?? 'DRAFT'),
              ],
            ),
          );
        });
        await c.attach(app);
        c.typeFilter.value = 'آرشیو';
        await c.init();
        expect(c.prd.single.status, 'ARCHIVED');
        c.typeFilter.value = 'همه';
        await c.init();
        expect(c.prd.single.status, 'DRAFT');
        await c.attach(app);
        expect(c.prd.single.status, 'DRAFT');
        expect(statuses, ['ACTIVE', 'ARCHIVED', null, null]);
      },
    );

    test(
      '$app multiple category selection covers every page without inventing an OR query',
      () async {
        const selectedCategory = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbc';
        final queries = <Map<String, String>>[];
        bind(app, (request) async {
          if (request.url.path.endsWith('/authorization')) {
            return jsonResponse(fixtureAuthorization(['pim.product.read']));
          }
          queries.add(request.url.queryParameters);
          final next = request.url.queryParameters['after'] != null;
          return jsonResponse(
            fixturePimPage(
              PimResource.products,
              items: [
                {
                  ...fixturePim(
                    PimResource.products,
                    id: next ? nextProduct : productId,
                  ),
                  'categoryIds': [next ? selectedCategory : categoryId],
                },
              ],
              next: next ? null : productId,
            ),
          );
        });
        await c.attach(app);
        c.filteredCatId.assignAll([
          selectedCategory,
          'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbd',
        ]);
        await c.init();
        expect(c.prd.single.id, nextProduct);
        expect(c.hasMore.value, isFalse);
        expect(
          queries.every((query) => !query.containsKey('categoryId')),
          isTrue,
        );
      },
    );

    test(
      '$app rejects repeated cursors instead of looping during search',
      () async {
        bind(
          app,
          (request) async => request.url.path.endsWith('/authorization')
              ? jsonResponse(fixtureAuthorization(['pim.product.read']))
              : productPage(next: productId),
        );
        await c.attach(app, query: 'پیراهن');
        expect(c.error.value, isNotNull);
        expect(c.prd, isEmpty);
        expect(c.loading.value, isFalse);
      },
    );

    test('$app denied access removes already displayed records', () async {
      var denied = false;
      bind(app, (request) async {
        if (request.url.path.endsWith('/authorization')) {
          return jsonResponse(fixtureAuthorization(['pim.product.read']));
        }
        if (denied) {
          return jsonResponse({
            'error': {'code': 'FORBIDDEN'},
          }, 403);
        }
        return productPage(next: productId);
      });
      await c.attach(app);
      denied = true;
      await c.loadMore();
      expect(c.prd, isEmpty);
      expect(c.hasMore.value, isFalse);
      expect(c.error.value, isNotNull);
    });

    test(
      '$app a failed next page can retry its same cursor without dropping current rows',
      () async {
        var fail = true;
        final cursors = <String?>[];
        bind(app, (request) async {
          if (request.url.path.endsWith('/authorization')) {
            return jsonResponse(fixtureAuthorization(['pim.product.read']));
          }
          cursors.add(request.url.queryParameters['after']);
          if (request.url.queryParameters['after'] == null) {
            return productPage(next: productId);
          }
          if (fail) throw http.ClientException('offline');
          return productPage(id: nextProduct);
        });
        await c.attach(app);
        await c.loadMore();
        expect(c.prd.single.id, productId);
        expect(c.moreError.value, isNotNull);
        fail = false;
        await c.loadMore();
        expect(c.prd, hasLength(2));
        expect(cursors, [null, productId, productId]);
        expect(c.moreError.value, isNull);
      },
    );

    test(
      '$app a stale response after logout cannot populate the list',
      () async {
        final response = Completer<http.Response>();
        final started = Completer<void>();
        final fx = pimFixture(
          MockClient((request) async {
            if (request.url.path.endsWith('/authorization')) {
              return jsonResponse(fixtureAuthorization(['pim.product.read']));
            }
            started.complete();
            return response.future;
          }),
          appId: app,
        );
        final loading = c.attach(app);
        await started.future;
        await fx.context.auth.clear();
        response.complete(productPage());
        await loading;
        expect(c.prd, isEmpty);
        expect(c.error.value, isNotNull);
      },
    );

    test(
      '$app reload uses category IDs and clears unsupported legacy filters explicitly',
      () async {
        final requests = <http.Request>[];
        bind(app, (request) async {
          requests.add(request);
          if (request.url.path.endsWith('/authorization')) {
            return jsonResponse(fixtureAuthorization(['pim.product.read']));
          }
          return productPage();
        });
        await c.attach(app);
        c.filteredCatId.add(categoryId);
        await c.init();
        expect(requests.last.url.queryParameters['categoryId'], categoryId);
        c.typeFilter.value = 'ناموجود';
        final before = requests.length;
        await c.init();
        expect(requests.length, before);
        expect(c.error.value, contains('فیلتر'));
        expect(c.prd, isEmpty);
      },
    );
  }
  test('category labels use only authorized category data', () async {
    bind('mik', (request) async {
      if (request.url.path.endsWith('/authorization')) {
        return jsonResponse(
          fixtureAuthorization([
            'pim.product.read',
            'pim.product.category.read',
          ]),
        );
      }
      if (request.url.path.endsWith('/categories')) {
        return jsonResponse(fixturePimPage(PimResource.categories));
      }
      return productPage();
    });
    await c.attach('mik');
    expect(c.categoryNames(c.prd.single), 'پوشاک');
    BusinessContext.clear('mik');
    await c.init();
    expect(c.prd, isEmpty);
  });
}
