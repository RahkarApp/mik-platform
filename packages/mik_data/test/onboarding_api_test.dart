import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/api.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/onboarding_result.dart';
import 'package:mik_data/source/remote/onboarding_store.dart';
import 'package:mik_data/utils/fx/business.dart';

import 'support/onboarding_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'catalog preserves leading zero codes and pages each parent separately',
    () async {
      final requests = <http.Request>[];
      final business = BusinessFX(
        session: fixtureSession(
          MockClient((request) async {
            requests.add(request);
            final parent = request.url.queryParameters['parentCode'];
            final after = request.url.queryParameters['after'];
            if (parent == null) return jsonResponse(fixtureCatalog());
            return jsonResponse({
              'version': 1,
              'items': [
                {
                  'id': after == null ? '0901' : '0902',
                  'name': 'زیرحوزه',
                  'parent': '09',
                },
              ],
              'nextCursor': after == null ? '0901' : null,
              'units': [],
            });
          }),
        ),
        store: MemoryOnboardingStore(),
      );
      expect((await business.categories()).single.id, '09');
      expect((await business.categories(parentCode: '09')).map((e) => e.id), [
        '0901',
        '0902',
      ]);
      expect(requests.last.url.queryParameters['after'], '0901');
      expect(
        requests.every((r) => !r.headers.containsKey('authorization')),
        isTrue,
      );
    },
  );
  test(
    'businesses page by numeric business id and retain membership types',
    () async {
      final business = BusinessFX(
        session: fixtureSession(
          MockClient((request) async {
            final second = request.url.queryParameters.containsKey('after');
            return jsonResponse({
              'items': [
                {
                  'businessId': second ? 23456789 : 12345678,
                  'name': 'میک',
                  'membershipId': membership,
                  'membershipType': second ? 'PERSONNEL' : 'OWNER',
                },
              ],
              'nextCursor': second ? null : 12345678,
            });
          }),
        ),
        store: MemoryOnboardingStore(),
      );
      final items = await business.businesses();
      expect(items.map((e) => e.businessId), [12345678, 23456789]);
      expect(items.last.membershipType, 'PERSONNEL');
    },
  );
  test('registration persists intent before sending and parses every response object', () async {
    final store = MemoryOnboardingStore();
    late http.Request sent;
    final business = BusinessFX(
      session: fixtureSession(
        MockClient((request) async {
          sent = request;
          if (store.values.isEmpty) {
            throw StateError('Intent must be durable before HTTP');
          }
          return jsonResponse(fixtureResult(), 201);
        }),
      ),
      store: store,
    );
    final result = await business.onboard(fixtureData());
    expect(sent.url.path, '/v1/businesses/onboarding');
    expect(sent.headers['authorization'], 'Bearer access');
    expect(sent.headers['x-app-id'], 'mik');
    expect(
      sent.headers['idempotency-key'],
      matches(RegExp(r'^[0-9a-f-]{36}$')),
    );
    expect(jsonDecode(sent.body), fixtureData().toJson());
    expect(jsonDecode(sent.body).containsKey('identityId'), isFalse);
    expect(result.profile.firstName, 'امین');
    expect(result.branch.branchId, result.settings.defaultBranchId);
    expect(result.warehouse.warehouseId, result.branch.defaultWarehouseId);
    expect(result.branchAccess.canIssueStock, isTrue);
    expect(result.authorization.permissionCodes, ['business.read']);
    expect(result.defaultCustomerId, 'customer-id');
    expect(business.current, same(result));
    expect(store.values, isEmpty);
  });
  test('503 then restart replays exactly the same key and body without automatic retry', () async {
    final store = MemoryOnboardingStore();
    final requests = <http.Request>[];
    final session = fixtureSession(
      MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return jsonResponse({
            'error': {'code': 'PIM_UNAVAILABLE', 'retryable': true},
          }, 503);
        }
        return jsonResponse(fixtureResult(replayed: true));
      }),
    );
    final first = BusinessFX(session: session, store: store);
    await expectLater(first.onboard(fixtureData()), throwsA(isA<AuthError>()));
    expect(requests, hasLength(1));
    final restarted = BusinessFX(session: session, store: store);
    final pending = await restarted.restoreAttempt();
    expect(pending, isNotNull);
    expect((await restarted.onboard(pending!.data)).replayed, isTrue);
    expect(
      requests.last.headers['idempotency-key'],
      requests.first.headers['idempotency-key'],
    );
    expect(requests.last.body, requests.first.body);
    expect(store.values, isEmpty);
  });
  test(
    'pending registration cannot be replaced by a changed payload',
    () async {
      var calls = 0;
      final business = BusinessFX(
        session: fixtureSession(
          MockClient((_) async {
            calls++;
            throw http.ClientException('offline');
          }),
        ),
        store: MemoryOnboardingStore(),
      );
      await expectLater(
        business.onboard(fixtureData()),
        throwsA(isA<http.ClientException>()),
      );
      await expectLater(
        business.onboard(fixtureData(businessName: 'نام دیگر')),
        throwsA(
          isA<AuthError>().having((e) => e.code, 'code', 'ONBOARDING_PENDING'),
        ),
      );
      expect(calls, 1);
    },
  );
  test('parallel submit shares one intent and one network request', () async {
    var calls = 0;
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final business = BusinessFX(
      session: fixtureSession(
        MockClient((_) {
          calls++;
          started.complete();
          return response.future;
        }),
      ),
      store: MemoryOnboardingStore(),
    );
    final one = business.onboard(fixtureData());
    await started.future;
    final two = business.onboard(fixtureData());
    await expectLater(
      business.onboard(fixtureData(businessName: 'نام متفاوت')),
      throwsA(
        isA<AuthError>().having((e) => e.code, 'code', 'ONBOARDING_PENDING'),
      ),
    );
    response.complete(jsonResponse(fixtureResult(), 201));
    expect(await one, same(await two));
    expect(calls, 1);
  });
  test('invalid referral allows corrections; malformed success retains the pending intent', () async {
    for (final malformed in [false, true]) {
      final store = MemoryOnboardingStore();
      final business = BusinessFX(
        session: fixtureSession(
          MockClient(
            (_) async => malformed
                ? jsonResponse({'business': {}})
                : jsonResponse({
                    'error': {'code': 'REFERRAL_INVALID'},
                  }, 400),
          ),
        ),
        store: store,
      );
      await expectLater(business.onboard(fixtureData()), throwsA(anything));
      expect(store.values.isNotEmpty, malformed);
    }
    final corrupt = fixtureResult();
    (corrupt['branch'] as Map)['businessId'] = 99999999;
    expect(() => OnboardingResult.fromJson(corrupt), throwsFormatException);
  });
  test(
    'secure pending intent survives new instances and is isolated by identity',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final session = fixtureSession(
        MockClient((_) async {
          throw http.ClientException('offline');
        }),
      );
      final first = BusinessFX(session: session);
      await expectLater(first.onboard(fixtureData()), throwsA(anything));
      final restored = BusinessFX(session: session);
      expect(
        (await restored.restoreAttempt())!.data.toJson(),
        fixtureData().toJson(),
      );
      expect(
        const SecureOnboardingStore().read('other-account'),
        completion(isNull),
      );
      expect(API.origin.origin, contains(':4000'));
    },
  );
}
