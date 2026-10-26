import 'package:mik_data/utils/saveHelper.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_variables/permissions.dart';

import 'support/pim_fixtures.dart';
import 'support/onboarding_fixtures.dart';

void main() {
  setUp(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    PermissionAccess.clear();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app uses the same PIM APIs and business scope with its own credentials',
      () async {
        final requests = <http.Request>[];
        final fx = pimFixture(
          MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('authorization')) {
              return jsonResponse(fixtureAuthorization(['pim.product.read']));
            }
            return jsonResponse(
              fixturePimPage(
                PimResource.products,
                items: request.url.queryParameters.containsKey('after')
                    ? []
                    : null,
                next: request.url.queryParameters.containsKey('after')
                    ? null
                    : productId,
              ),
            );
          }),
          appId: app,
        );
        await fx.authorize();
        final rows = await fx.all(PimResource.products);
        expect(rows.single.name, 'پیراهن');
        expect(requests.first.url.queryParameters, {
          'scopeType': 'BUSINESS',
          'scopeId': '12345678',
        });
        expect(requests.last.url.queryParameters['after'], productId);
        for (final request in requests) {
          expect(request.url.host, '192.168.3.48');
          expect(request.url.port, 4000);
          expect(request.headers['authorization'], 'Bearer access');
          expect(request.headers['x-app-id'], app);
          expect(
            request.url.path.startsWith('/v1/businesses/12345678/'),
            isTrue,
          );
        }
      },
    );
  }
  test('a legacy owner flag never grants PIM permissions to MiKYar', () async {
    PermissionAccess.useOwner();
    var requests = 0;
    final fx = pimFixture(
      MockClient((request) async {
        requests++;
        return jsonResponse(fixtureAuthorization(['pim.product.read']));
      }),
      appId: 'mikyar',
    );
    await fx.authorize();
    await expectLater(
      fx.all(PimResource.prices),
      throwsA(isA<AuthError>().having((e) => e.statusCode, 'status', 403)),
    );
    await expectLater(
      SaveHelper.savePim(
        fx,
        fx.change(PimResource.products, {'name': 'ممنوع'}),
      ),
      throwsA(isA<AuthError>()),
    );
    expect(requests, 1);
    expect(fx.has('pim.price.read'), isFalse);
  });
  for (final resource in [
    PimResource.attributes,
    PimResource.prices,
    PimResource.overrides,
  ]) {
    test(
      '${resource.name} update/archive of another user needs base and all grants',
      () async {
        final permissions = <String>[
          '${resource.permission}.update',
          resource.archivePermission,
        ];
        final requests = <http.Request>[];
        final fx = pimFixture(
          MockClient((request) async {
            requests.add(request);
            return jsonResponse(fixtureAuthorization(permissions));
          }),
          appId: 'mikyar',
        );
        await fx.authorize();
        final other = resource.parse(
          fixturePim(resource, creator: 'other-identity'),
        );
        final own = resource.parse(fixturePim(resource));
        expect(fx.canChange(resource, own), isTrue);
        expect(fx.canChange(resource, other), isFalse);
        expect(fx.canChange(resource, other, archive: true), isFalse);
        await expectLater(
          SaveHelper.savePim(
            fx,
            fx.change(resource, {'status': 'ARCHIVED'}, item: other),
          ),
          throwsA(isA<AuthError>()),
        );
        expect(requests, hasLength(1));
        permissions.addAll([
          '${resource.permission}.update.all',
          '${resource.archivePermission}.all',
        ]);
        await fx.authorize();
        expect(fx.canChange(resource, other), isTrue);
        expect(fx.canChange(resource, other, archive: true), isTrue);
        permissions.remove('${resource.permission}.update');
        await fx.authorize();
        expect(fx.canChange(resource, other), isFalse);
      },
    );
  }
  test(
    'uncertain mutations persist an immutable body and key across instances',
    () async {
      final store = MemoryPimStore();
      final requests = <http.Request>[];
      final fx = pimFixture(
        MockClient((request) async {
          if (request.url.path.endsWith('authorization')) {
            return jsonResponse(fixtureAuthorization(['pim.brand.create']));
          }
          requests.add(request);
          if (requests.length == 1) throw http.ClientException('offline');
          return jsonResponse({
            'businessId': 12345678,
            'item': fixturePim(PimResource.brands),
            'replayed': true,
          });
        }),
        store: store,
      );
      await fx.authorize();
      final fields = <String, dynamic>{'name': 'برند نمونه'};
      final command = fx.change(PimResource.brands, fields);
      fields['name'] = 'تغییر بعدی';
      await expectLater(
        SaveHelper.savePim(fx, command),
        throwsA(isA<http.ClientException>()),
      );
      expect(store.values, isNotEmpty);
      final resumed = PimFX(context: fx.context, store: store);
      await resumed.authorize();
      final saved = await resumed.restore();
      expect(
        () => resumed.change(PimResource.brands, {'name': 'جدید'}),
        throwsA(isA<AuthError>()),
      );
      await resumed.execute(saved!);
      expect(requests.last.body, requests.first.body);
      expect(jsonDecode(requests.first.body), {'name': 'برند نمونه'});
      expect(
        requests.last.headers['idempotency-key'],
        requests.first.headers['idempotency-key'],
      );
      expect(store.values, isEmpty);
    },
  );
  test('updates carry revision and archive via PATCH without DELETE', () async {
    late http.Request sent;
    final fx = pimFixture(
      MockClient((request) async {
        if (request.url.path.endsWith('authorization')) {
          return jsonResponse(fixtureAuthorization(['pim.product.archive']));
        }
        sent = request;
        return jsonResponse({
          'businessId': 12345678,
          'item': fixturePim(PimResource.products, status: 'ARCHIVED')
            ..['revision'] = 4,
          'replayed': false,
        });
      }),
    );
    await fx.authorize();
    final item = PimProduct.fromJson(fixturePim(PimResource.products));
    await SaveHelper.savePim(
      fx,
      fx.change(PimResource.products, {'status': 'ARCHIVED'}, item: item),
    );
    expect(sent.method, 'PATCH');
    expect(sent.url.path, '/v1/businesses/12345678/pim/products/$productId');
    expect(jsonDecode(sent.body), {
      'status': 'ARCHIVED',
      'expectedRevision': 3,
    });
    expect(sent.headers['idempotency-key'], isNotEmpty);
  });
  test('malformed success retains pending command, revision conflict permits reload', () async {
    var conflict = false;
    final fx = pimFixture(
      MockClient((request) async {
        if (request.url.path.endsWith('authorization')) {
          return jsonResponse(fixtureAuthorization(['pim.product.update']));
        }
        if (conflict) {
          return jsonResponse({
            'error': {'code': 'REVISION_CONFLICT'},
          }, 409);
        }
        return jsonResponse({
          'businessId': 87654321,
          'item': fixturePim(PimResource.products),
          'replayed': false,
        });
      }),
    );
    await fx.authorize();
    final command = fx.change(PimResource.products, {
      'name': 'جدید',
    }, item: PimProduct.fromJson(fixturePim(PimResource.products)));
    await expectLater(
      SaveHelper.savePim(fx, command),
      throwsA(isA<FormatException>()),
    );
    expect(fx.pending, isNotNull);
    conflict = true;
    await expectLater(
      SaveHelper.savePim(fx, command),
      throwsA(
        isA<AuthError>().having((e) => e.code, 'code', 'REVISION_CONFLICT'),
      ),
    );
    expect(fx.pending, isNull);
  });
  test(
    'forbidden reads revoke local actions and require fresh authorization',
    () async {
      var permission = true;
      final fx = pimFixture(
        MockClient((request) async {
          if (request.url.path.endsWith('authorization')) {
            return jsonResponse(
              fixtureAuthorization(
                permission ? ['pim.product.read', 'pim.product.create'] : [],
              ),
            );
          }
          permission = false;
          return jsonResponse({
            'error': {'code': 'FORBIDDEN'},
          }, 403);
        }),
        appId: 'mikyar',
      );
      await fx.authorize();
      await expectLater(
        fx.all(PimResource.products),
        throwsA(isA<AuthError>()),
      );
      expect(fx.has('pim.product.create'), isFalse);
      await fx.authorize();
      expect(fx.has('pim.product.read'), isFalse);
    },
  );
  test('business/scope/membership mismatch is rejected', () async {
    for (final mismatch in [
      {'scopeType': 'BRANCH'},
      {'businessId': 87654321},
      {'membershipId': 'another-membership'},
    ]) {
      final fx = pimFixture(
        MockClient(
          (request) async => jsonResponse({
            ...fixtureAuthorization(['pim.product.read']),
            ...mismatch,
          }),
        ),
      );
      await expectLater(fx.authorize(), throwsA(isA<FormatException>()));
    }
  });
  test(
    'in-flight data from a previous business cannot populate the next business',
    () async {
      final response = Completer<http.Response>();
      final fx = pimFixture(
        MockClient((request) async {
          if (request.url.path.endsWith('authorization')) {
            return jsonResponse(fixtureAuthorization(['pim.product.read']));
          }
          return response.future;
        }),
      );
      await fx.authorize();
      final read = fx.all(PimResource.products);
      final expectation = expectLater(read, throwsA(isA<AuthError>()));
      BusinessContext.activate(
        fx.context.auth,
        BusinessSession(
          identityId: identity,
          business: const BusinessSummary(
            businessId: 87654321,
            name: 'دوم',
            membershipId: membership,
            membershipType: 'OWNER',
          ),
        ),
      );
      response.complete(jsonResponse(fixturePimPage(PimResource.products)));
      await expectation;
    },
  );
  test('zero effective price is valid and unavailable price never picks another title', () async {
    var unavailable = false;
    final requests = <http.Request>[];
    final fx = pimFixture(
      MockClient((request) async {
        if (request.url.path.endsWith('authorization')) {
          return jsonResponse(fixtureAuthorization(['pim.price.read']));
        }
        requests.add(request);
        if (unavailable) {
          return jsonResponse({
            'error': {'code': 'PRICE_UNAVAILABLE'},
          }, 422);
        }
        return jsonResponse({
          'businessId': 12345678,
          'productId': productId,
          'variantId': variantId,
          'productPriceId': priceId,
          'amount': 0,
          'currency': 'TOMAN',
          'source': 'PRODUCT_BASE',
        });
      }),
    );
    await fx.authorize();
    expect((await fx.effectivePrice(variantId, priceId: priceId)).amount, 0);
    unavailable = true;
    await expectLater(
      fx.effectivePrice(variantId, priceId: priceId),
      throwsA(
        isA<AuthError>().having((e) => e.code, 'code', 'PRICE_UNAVAILABLE'),
      ),
    );
    expect(requests, hasLength(2));
    expect(requests.last.url.queryParameters, {'productPriceId': priceId});
  });
  test('repeated cursors and cross-business pages fail explicitly', () async {
    var wrongBusiness = false;
    final fx = pimFixture(
      MockClient((request) async {
        if (request.url.path.endsWith('authorization')) {
          return jsonResponse(fixtureAuthorization(['pim.product.read']));
        }
        return jsonResponse(
          wrongBusiness
              ? {
                  ...fixturePimPage(PimResource.products),
                  'businessId': 87654321,
                }
              : fixturePimPage(PimResource.products, next: productId),
        );
      }),
    );
    await fx.authorize();
    await expectLater(
      fx.all(PimResource.products),
      throwsA(isA<FormatException>()),
    );
    wrongBusiness = true;
    await expectLater(
      fx.all(PimResource.products),
      throwsA(isA<FormatException>()),
    );
  });
  test(
    'catalog codes keep leading zeros and preview has no mutation key',
    () async {
      final requests = <http.Request>[];
      final fx = pimFixture(
        MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('authorization')) {
            return jsonResponse(
              fixtureAuthorization(['pim.variant.create', 'pim.product.read']),
            );
          }
          if (request.url.path.endsWith('/preview')) {
            return jsonResponse({
              'productId': productId,
              'combinations': [[]],
            });
          }
          return jsonResponse(
            fixtureCatalog(parent: request.url.queryParameters['parentCode']),
          );
        }),
      );
      await fx.authorize();
      expect((await fx.catalog(parentCode: '09')).items.single.id, '0902');
      expect((await fx.preview(productId)).combinations.single, isEmpty);
      expect(requests.last.headers.containsKey('idempotency-key'), isFalse);
    },
  );
}
