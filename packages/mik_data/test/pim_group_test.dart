import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/source/remote/pim_group_store.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/pim_group.dart';

import 'support/onboarding_fixtures.dart';
import 'support/pim_fixtures.dart';

class MemoryGroupStore implements PimGroupStore {
  final values = <String, PimGroupState>{};
  int writes = 0;
  int? failAt;
  @override
  Future<PimGroupState> read(String key) async =>
      values[key] ?? const PimGroupState();
  @override
  Future<void> write(String key, PimGroupState state) async {
    if (++writes == failAt) throw StateError('Storage temporarily unavailable');
    values[key] = PimGroupState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
    );
  }
}

PimProductDraft draft(String id, String name, {bool price = true}) =>
    PimProductDraft(
      id: id,
      name: name,
      fields: {
        'name': name,
        'categoryIds': [categoryId],
        'primaryCategoryId': categoryId,
        'unitId': 1,
      },
      prices: price
          ? [const PimDraftPrice(name: 'فروش', amount: 0, isDefault: true)]
          : [],
    );

void main() {
  test('batch retry after reopening resumes the failed price without recreating products', () async {
    final store = MemoryGroupStore();
    final commands = MemoryPimStore();
    final prices = <http.Request>[];
    var creates = 0, activations = 0;
    final fx = pimFixture(
      MockClient((request) async {
        if (request.url.path.endsWith('authorization')) {
          return jsonResponse(
            fixtureAuthorization([
              'pim.product.create',
              'pim.product.update',
              'pim.price.create',
              'pim.price.default.update',
            ]),
          );
        }
        if (request.url.path.endsWith('/products')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          creates++;
          return jsonResponse({
            'businessId': 12345678,
            'item': fixturePim(
              PimResource.products,
              id: body['name'] == 'اول' ? productId : categoryId,
              name: body['name'] as String,
              status: 'DRAFT',
            ),
            'replayed': false,
          });
        }
        if (request.url.path.endsWith('/prices')) {
          prices.add(request);
          if (prices.length == 1) {
            return jsonResponse({
              'error': {'code': 'UNAVAILABLE', 'retryable': true},
            }, 503);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse({
            'businessId': 12345678,
            'item': {
              ...fixturePim(PimResource.prices),
              'productId': body['productId'],
            },
            'replayed': false,
          });
        }
        activations++;
        return jsonResponse({
          'businessId': 12345678,
          'item': fixturePim(
            PimResource.products,
            id: request.url.pathSegments.last,
          ),
          'replayed': false,
        });
      }),
      store: commands,
    );
    await fx.authorize();
    final group = PimGroupFX(fx, store: store);
    await expectLater(
      group.save([draft('first', 'اول'), draft('second', 'دوم')]),
      throwsA(isA<AuthError>()),
    );
    expect(creates, 2);
    expect((await group.read()).pending, isTrue);
    final restoredFX = PimFX(context: fx.context, store: commands);
    await restoredFX.authorize();
    final restored = PimGroupFX(restoredFX, store: store);
    await restored.save([]);
    expect(creates, 2);
    expect(activations, 2);
    expect(prices, hasLength(3));
    expect(prices[0].body, prices[1].body);
    expect(
      prices[0].headers['idempotency-key'],
      prices[1].headers['idempotency-key'],
    );
    expect((await restored.read()).pending, isFalse);
    expect((await restored.read()).drafts, isEmpty);
  });

  test('lost local checkpoint replays the same product creation key', () async {
    final store = MemoryGroupStore()..failAt = 2;
    final requests = <http.Request>[];
    final fx = pimFixture(
      MockClient((request) async {
        if (request.url.path.endsWith('authorization')) {
          return jsonResponse(fixtureAuthorization(['pim.product.create']));
        }
        requests.add(request);
        return jsonResponse({
          'businessId': 12345678,
          'item': fixturePim(PimResource.products, status: 'DRAFT'),
          'replayed': requests.length > 1,
        });
      }),
    );
    await fx.authorize();
    final group = PimGroupFX(fx, store: store);
    await expectLater(
      group.save([draft('first', 'اول', price: false)]),
      throwsStateError,
    );
    await PimGroupFX(fx, store: store).save([]);
    expect(requests, hasLength(2));
    expect(
      requests[0].headers['idempotency-key'],
      requests[1].headers['idempotency-key'],
    );
    expect(requests[0].body, requests[1].body);
  });

  test('MiKYar cannot submit prices without the server grant', () async {
    var mutations = 0;
    final fx = pimFixture(
      MockClient((request) async {
        if (request.url.path.endsWith('authorization')) {
          return jsonResponse(fixtureAuthorization(['pim.product.create']));
        }
        mutations++;
        throw StateError('Unauthorized price intent must not start a batch');
      }),
      appId: 'mikyar',
    );
    await fx.authorize();
    final group = PimGroupFX(fx, store: MemoryGroupStore());
    await expectLater(
      group.save([draft('first', 'اول')]),
      throwsA(
        isA<AuthError>().having((error) => error.code, 'code', 'FORBIDDEN'),
      ),
    );
    expect(mutations, 0);
    expect((await group.read()).pending, isFalse);
  });

  test('conversation drafts are isolated between the two apps', () async {
    final store = MemoryGroupStore();
    final client = MockClient(
      (_) async => throw StateError('No HTTP expected'),
    );
    final mik = PimGroupFX(pimFixture(client), store: store);
    await mik.add('محصول میک');
    final yar = PimGroupFX(pimFixture(client, appId: 'mikyar'), store: store);
    await yar.add('محصول میکیار');
    expect((await mik.read()).drafts.single.name, 'محصول میک');
    expect((await yar.read()).drafts.single.name, 'محصول میکیار');
  });
}
