import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_data/source/remote/auth_store.dart';
import 'package:mik_data/source/remote/models/auth_session.dart';
import 'package:mik_data/utils/fx/auth.dart';
import 'package:mik_pages/login/components/success.dart';
import 'package:mik_pages/login/screen/screen.dart';
import 'package:toastification/toastification.dart';

class MemoryStore implements AuthSessionStore {
  AuthSession? value;
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async => value = session;
  @override
  Future<void> clear() async => value = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const sms = MethodChannel('sms_autofill');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sms, (_) async => null);
  });
  tearDown(() {
    toastification.dismissAll(delayForAnimation: false);
    Get.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sms, null);
  });

  for (final app in ['mik', 'mikyar']) {
    testWidgets('$app revoked stored session returns to the phone form', (
      tester,
    ) async {
      final store = MemoryStore()
        ..value = AuthSession(
          identityId: 'identity',
          sessionId: 'session',
          accessToken: 'expired',
          refreshToken: 'revoked',
          accessExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          refreshExpiresAt: DateTime.now().add(const Duration(days: 1)),
        );
      final auth = AuthFX(
        appId: app,
        store: store,
        client: MockClient(
          (_) async =>
              http.Response('{"error":{"code":"REFRESH_TOKEN_INVALID"}}', 401),
        ),
      );
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            home: LoginScreen(
              appId: app,
              session: auth,
              onAuthenticated: (_, _) async =>
                  fail('A revoked session cannot log in'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('لطفا شماره موبایل خود را وارد کنید.'), findsOneWidget);
      expect(loading.value, isFalse);
      expect(store.value, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('$app requests OTP, verifies five digits and logs out', (
      tester,
    ) async {
      final store = MemoryStore();
      final paths = <String>[];
      final requests = <http.Request>[];
      final registrations = <bool>[];
      var authenticated = 0;
      final auth = AuthFX(
        appId: app,
        store: store,
        client: MockClient((request) async {
          paths.add(request.url.path);
          requests.add(request);
          if (request.url.path.endsWith('/verify')) {
            return http.Response(
              jsonEncode({
                'identityId': 'identity',
                'sessionId': 'session',
                'subjectType': 'WORKFORCE',
                'accessToken': 'access',
                'refreshToken': 'refresh',
                'accessTokenExpiresInSeconds': 300,
                'refreshTokenExpiresInSeconds': 3600,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/logout')) {
            return http.Response('{"revoked":true}', 200);
          }
          return http.Response('{"accepted":true}', 202);
        }),
      );
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            home: LoginScreen(
              appId: app,
              session: auth,
              allowRegistration: app == 'mik',
              onAuthenticated: (_, registration) async {
                registrations.add(registration);
                authenticated++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '09123456789');
      final button = tester.widget<BTN>(find.byType(BTN).first);
      await button.onTap();
      await tester.pumpAndSettle();
      expect(find.textContaining('کد تایید ۵ رقمی'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '54321');
      await tester.pumpAndSettle();
      expect(paths, ['/v1/auth/otp', '/v1/auth/otp/verify']);
      expect(find.text('ورود انجام نشد. دوباره تلاش کنید.'), findsNothing);
      expect(authenticated, 1);
      expect(registrations, [false]);
      expect(jsonDecode(requests[0].body), {'phone': '+989123456789'});
      expect(jsonDecode(requests[1].body), {
        'phone': '+989123456789',
        'otp': '54321',
      });
      expect(store.value?.accessToken, 'access');
      expect(find.byType(LoginSuccess), findsOneWidget);
      await tester.tap(find.text('خروج از حساب'));
      await tester.pumpAndSettle();
      expect(store.value, isNull);
      expect(requests.last.headers['authorization'], 'Bearer access');
      expect(requests.map((r) => r.headers['x-app-id']), everyElement(app));
      expect(paths, ['/v1/auth/otp', '/v1/auth/otp/verify', '/v1/auth/logout']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
