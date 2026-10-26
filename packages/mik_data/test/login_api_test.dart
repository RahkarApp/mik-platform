import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/auth_session.dart';
import 'package:mik_data/source/remote/api.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/auth_store.dart';
import 'package:mik_data/utils/fx/auth.dart';

class MemoryAuthStore implements AuthSessionStore {
  AuthSession? value;
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

Map<String, Object> sessionResponse() => {
  'identityId': 'identity-id',
  'sessionId': 'session-id',
  'subjectType': 'WORKFORCE',
  'accessToken': 'access-secret',
  'refreshToken': 'refresh-secret',
  'accessTokenExpiresInSeconds': 300,
  'refreshTokenExpiresInSeconds': 2592000,
};

AuthSession expiredAccess() => AuthSession(
  identityId: 'i',
  sessionId: 's',
  accessToken: 'old',
  refreshToken: 'refresh',
  accessExpiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
  refreshExpiresAt: DateTime.now().add(const Duration(days: 1)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gateway defaults to the local HTTP server and retains the port', () {
    expect(
      API.origin.origin,
      const String.fromEnvironment(
        'API_ORIGIN',
        defaultValue: 'http://192.168.3.48:4000',
      ),
    );
  });

  test(
    'all JSON methods use common headers, query and body encoding',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(utf8.encode('{"name":"میک"}'), 200);
      });
      for (final method in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
        final data = method == 'GET' ? null : {'name': 'نام جدید'};
        expect(
          await API.request(
            method,
            '/v1/businesses',
            data: data,
            query: {'search': 'فروشگاه', 'limit': '20'},
            appId: 'mikyar',
            accessToken: 'access',
            branchId: 'branch',
            idempotencyKey: 'intent',
            client: client,
          ),
          {'name': 'میک'},
        );
        final request = requests.last;
        expect(request.method, method);
        expect(request.url.origin, API.origin.origin);
        expect(request.url.path, '/v1/businesses');
        expect(request.url.queryParameters, {
          'search': 'فروشگاه',
          'limit': '20',
        });
        expect(request.headers['x-app-id'], 'mikyar');
        expect(request.headers['x-app-version'], isNotEmpty);
        expect(request.headers['x-app-platform'], isNotEmpty);
        expect(request.headers['accept'], 'application/json');
        expect(request.headers['content-type'], startsWith('application/json'));
        expect(request.headers['authorization'], 'Bearer access');
        expect(request.headers['x-branch-id'], 'branch');
        expect(request.headers['idempotency-key'], 'intent');
        if (data == null) {
          expect(request.body, isEmpty);
        } else {
          expect(jsonDecode(request.body), data);
          expect(data.containsKey('app'), isFalse);
        }
      }
      expect(requests, hasLength(5));
    },
  );

  test(
    'public requests omit optional headers and accept no-content responses',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('', request.method == 'HEAD' ? 200 : 204);
      });
      for (final method in ['DELETE', 'HEAD']) {
        expect(
          await API.request(method, '/v1/resource', client: client),
          isNull,
        );
        final headers = requests.last.headers;
        expect(headers.containsKey('authorization'), isFalse);
        expect(headers.containsKey('x-branch-id'), isFalse);
        expect(headers.containsKey('idempotency-key'), isFalse);
      }
    },
  );

  test('request rejects external URLs before sending credentials', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    for (final path in [
      'https://other.example/v1',
      '//other.example/v1',
      '/v1?a=b',
    ]) {
      await expectLater(
        API.request('GET', path, accessToken: 'secret', client: client),
        throwsArgumentError,
      );
    }
    expect(calls, 0);
  });

  test(
    'request preserves structured errors and does not replay mutations',
    () async {
      var calls = 0;
      await expectLater(
        API.request(
          'POST',
          '/v1/businesses',
          data: {'name': 'میک'},
          idempotencyKey: 'same-intent',
          client: MockClient((_) async {
            calls++;
            return http.Response(
              '{"error":{"code":"BUSINESS_UNAVAILABLE","retryable":true}}',
              503,
              headers: {'x-request-id': 'trace'},
            );
          }),
        ),
        throwsA(
          isA<AuthError>()
              .having((e) => e.code, 'code', 'BUSINESS_UNAVAILABLE')
              .having((e) => e.retryable, 'retryable', isTrue)
              .having((e) => e.requestId, 'requestId', 'trace'),
        ),
      );
      expect(calls, 1);
    },
  );

  test(
    'request rejects non-JSON responses and times out without retrying',
    () async {
      await expectLater(
        API.request(
          'GET',
          '/v1/businesses',
          client: MockClient(
            (_) async => http.Response('<html>error</html>', 502),
          ),
        ),
        throwsA(
          isA<AuthError>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
        ),
      );
      var calls = 0;
      final pending = Completer<http.Response>();
      await expectLater(
        API.request(
          'GET',
          '/v1/businesses',
          timeout: const Duration(milliseconds: 1),
          client: MockClient((_) {
            calls++;
            return pending.future;
          }),
        ),
        throwsA(isA<TimeoutException>()),
      );
      pending.complete(http.Response('{}', 200));
      expect(calls, 1);
    },
  );

  test(
    'authenticated requests refresh first and share gateway transport',
    () async {
      final requests = <http.Request>[];
      final store = MemoryAuthStore()..value = expiredAccess();
      final auth = AuthFX(
        appId: 'mikyar',
        store: store,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/refresh')) {
            return http.Response(
              '{"accessToken":"new","refreshToken":"rotated","accessTokenExpiresInSeconds":300}',
              200,
            );
          }
          return http.Response('{"items":[]}', 200);
        }),
      );
      auth.current = store.value;
      expect(
        await auth.request('GET', '/v1/businesses', query: {'limit': '20'}),
        {'items': []},
      );
      expect(requests.map((r) => r.url.path), [
        '/v1/auth/token/refresh',
        '/v1/businesses',
      ]);
      expect(requests.first.headers.containsKey('authorization'), isFalse);
      expect(requests.last.headers['authorization'], 'Bearer new');
      expect(requests.every((r) => r.headers['x-app-id'] == 'mikyar'), isTrue);
      expect(store.value?.refreshToken, 'rotated');
    },
  );

  test(
    'authenticated requests keep forbidden sessions and clear revoked sessions',
    () async {
      for (final code in ['PERMISSION_DENIED', 'SESSION_INVALID']) {
        var calls = 0;
        final store = MemoryAuthStore()
          ..value = AuthSession.fromJson(sessionResponse());
        final auth = AuthFX(
          appId: 'mik',
          store: store,
          client: MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({
                'error': {'code': code},
              }),
              code == 'SESSION_INVALID' ? 401 : 403,
            );
          }),
        );
        auth.current = store.value;
        await expectLater(
          auth.request('GET', '/v1/businesses'),
          throwsA(isA<AuthError>()),
        );
        expect(store.value == null, code == 'SESSION_INVALID');
        expect(calls, 1);
      }
    },
  );

  for (final app in ['mik', 'mikyar']) {
    test('$app uses the common login endpoint and normalized phone', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/v1/auth/otp');
        expect(jsonDecode(request.body), {'phone': '+989123456789'});
        expect(request.headers['x-app-id'], app);
        expect(request.headers['x-app-version'], isNotEmpty);
        expect(request.headers['x-app-platform'], isNotEmpty);
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('{"accepted":true}', 202);
      });
      expect(
        await API.login('login', '۰۹۱۲۳۴۵۶۷۸۹', appId: app, client: client),
        '200',
      );
      expect(calls, 1);
    });

    test(
      '$app sends the actual five digit OTP and saves both tokens',
      () async {
        final store = MemoryAuthStore();
        final auth = AuthFX(
          appId: app,
          store: store,
          client: MockClient((request) async {
            expect(request.url.path, '/v1/auth/otp/verify');
            expect(jsonDecode(request.body), {
              'phone': '+989123456789',
              'otp': '54321',
            });
            return http.Response(jsonEncode(sessionResponse()), 200);
          }),
        );
        await auth.signIn('09123456789', '۵۴۳۲۱');
        expect(store.value?.accessToken, 'access-secret');
        expect(store.value?.refreshToken, 'refresh-secret');
        expect(store.value?.identityId, 'identity-id');
        expect(store.value.toString(), isNot(contains('secret')));
      },
    );
  }

  test(
    'registration uses its own request and verification endpoints',
    () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        return request.url.path.endsWith('verify')
            ? http.Response(jsonEncode(sessionResponse()), 200)
            : http.Response('{"accepted":true}', 202);
      });
      await API.login('reg', '09123456789', client: client);
      await API.auth(
        {'phone': '09123456789', 'otp': '54321'},
        registration: true,
        client: client,
      );
      expect(paths, [
        '/v1/auth/registration/otp',
        '/v1/auth/registration/otp/verify',
      ]);
    },
  );

  test('MiKYar never requests or verifies registration', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    await expectLater(
      API.login('reg', '09123456789', appId: 'mikyar', client: client),
      throwsA(isA<AuthError>()),
    );
    await expectLater(
      API.auth(
        {'phone': '09123456789', 'otp': '54321'},
        registration: true,
        appId: 'mikyar',
        client: client,
      ),
      throwsA(isA<AuthError>()),
    );
    expect(calls, 0);
  });

  test(
    'four and six digit codes are rejected before making a request',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      for (final code in ['1234', '123456']) {
        await expectLater(
          API.auth({'phone': '09123456789', 'otp': code}, client: client),
          throwsA(isA<AuthError>()),
        );
      }
      expect(calls, 0);
    },
  );

  for (final code in [
    'USER_NOT_FOUND',
    'USER_NOT_ACTIVE',
    'OTP_WAIT',
    'INVALID_OTP',
    'IDENTITY_INTERNAL_ERROR',
  ]) {
    test(
      '$code is preserved without guessing account existence or retrying',
      () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'error': {'code': code, 'retryable': false},
            }),
            400,
            headers: {'x-request-id': 'request-1'},
          );
        });
        await expectLater(
          API.login('login', '09123456789', client: client),
          throwsA(
            isA<AuthError>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.requestId, 'requestId', 'request-1'),
          ),
        );
        expect(calls, 1);
      },
    );
  }

  test(
    'invalid OTP and malformed responses cannot overwrite a saved session',
    () async {
      for (final response in [
        http.Response('{"error":{"code":"INVALID_OTP"}}', 401),
        http.Response('{}', 200),
      ]) {
        final original = AuthSession.fromJson(sessionResponse());
        final store = MemoryAuthStore()..value = original;
        final auth = AuthFX(
          appId: 'mik',
          store: store,
          client: MockClient((_) async => response),
        );
        await expectLater(
          auth.signIn('09123456789', '54321'),
          throwsA(anything),
        );
        expect(identical(store.value, original), isTrue);
        expect(auth.current, isNull);
      }
    },
  );

  test(
    'concurrent requests rotate once and retain the original session expiry',
    () async {
      final original = expiredAccess();
      final store = MemoryAuthStore()..value = original;
      var refreshes = 0;
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final auth = AuthFX(
        appId: 'mik',
        store: store,
        client: MockClient((request) async {
          refreshes++;
          expect(request.url.path, '/v1/auth/token/refresh');
          expect(jsonDecode(request.body), {'refreshToken': 'refresh'});
          started.complete();
          return response.future;
        }),
      );
      final restoring = auth.restore();
      await started.future;
      final tokens = Future.wait([auth.accessToken(), auth.accessToken()]);
      response.complete(
        http.Response(
          '{"accessToken":"new","refreshToken":"rotated","accessTokenExpiresInSeconds":300}',
          200,
        ),
      );
      expect(await restoring, isTrue);
      expect(await tokens, ['new', 'new']);
      expect(refreshes, 1);
      expect(store.value?.refreshToken, 'rotated');
      expect(store.value?.refreshExpiresAt, original.refreshExpiresAt);
    },
  );

  test('a late refresh cannot restore a session after local logout', () async {
    final store = MemoryAuthStore()..value = expiredAccess();
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final auth = AuthFX(
      appId: 'mikyar',
      store: store,
      client: MockClient((_) async {
        started.complete();
        return response.future;
      }),
    );
    final restoring = auth.restore();
    await started.future;
    await auth.clear();
    response.complete(
      http.Response(
        '{"accessToken":"new","refreshToken":"rotated","accessTokenExpiresInSeconds":300}',
        200,
      ),
    );
    expect(await restoring, isFalse);
    expect(auth.current, isNull);
    expect(store.value, isNull);
  });

  test(
    'revoked refresh clears credentials; a network error retains them',
    () async {
      for (final revoked in [false, true]) {
        final original = expiredAccess();
        final store = MemoryAuthStore()..value = original;
        final auth = AuthFX(
          appId: 'mik',
          store: store,
          client: MockClient((_) async {
            if (!revoked) throw http.ClientException('offline');
            return http.Response(
              '{"error":{"code":"REFRESH_TOKEN_INVALID"}}',
              401,
            );
          }),
        );
        if (revoked) {
          expect(await auth.restore(), isFalse);
        } else {
          await expectLater(auth.restore(), throwsA(anything));
        }
        expect(store.value, revoked ? isNull : same(original));
      }
    },
  );

  for (final app in ['mik', 'mikyar']) {
    test('$app late logout does not clear a newer login', () async {
      final store = MemoryAuthStore()
        ..value = AuthSession.fromJson(sessionResponse());
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final auth = AuthFX(
        appId: app,
        store: store,
        client: MockClient((request) async {
          if (request.url.path == '/v1/auth/logout') {
            expect(request.headers['authorization'], 'Bearer access-secret');
            started.complete();
            return response.future;
          }
          return http.Response(
            jsonEncode({...sessionResponse(), 'accessToken': 'new-login'}),
            200,
          );
        }),
      );
      expect(await auth.restore(), isTrue);
      final logout = auth.signOut();
      await started.future;
      await auth.signIn('09123456789', '54321');
      response.complete(http.Response('{"revoked":true}', 200));
      await logout;
      expect(auth.current?.accessToken, 'new-login');
      expect(store.value?.accessToken, 'new-login');
    });

    test('$app new session does not reuse an older refresh', () async {
      final store = MemoryAuthStore()..value = expiredAccess();
      final started = Completer<void>();
      final response = Completer<http.Response>();
      var refreshes = 0;
      final auth = AuthFX(
        appId: app,
        store: store,
        client: MockClient((request) async {
          refreshes++;
          if (refreshes == 1) {
            started.complete();
            return response.future;
          }
          return http.Response(
            '{"accessToken":"current","refreshToken":"current-refresh","accessTokenExpiresInSeconds":300}',
            200,
          );
        }),
      );
      final previous = auth.restore();
      await started.future;
      await auth.clear();
      await store.write(expiredAccess());
      final restoring = auth.restore();
      // The old response arrives after the new session began restoring.
      await Future<void>.delayed(Duration.zero);
      response.complete(
        http.Response(
          '{"accessToken":"stale","refreshToken":"stale-refresh","accessTokenExpiresInSeconds":300}',
          200,
        ),
      );
      expect(await previous, isFalse);
      expect(await restoring, isTrue);
      expect(refreshes, 2);
      expect(auth.current?.accessToken, 'current');
      expect(store.value?.accessToken, 'current');
    });
  }

  test(
    'secure storage separates apps and drops malformed saved sessions',
    () async {
      FlutterSecureStorage.setMockInitialValues({'broken': '{broken'});
      const first = SecureAuthSessionStore(key: 'mik-test');
      const second = SecureAuthSessionStore(key: 'mikyar-test');
      await first.write(AuthSession.fromJson(sessionResponse()));
      expect((await first.read())?.refreshToken, 'refresh-secret');
      expect(await second.read(), isNull);
      expect(await const SecureAuthSessionStore(key: 'broken').read(), isNull);
      await first.clear();
      expect(await first.read(), isNull);
    },
  );
}
