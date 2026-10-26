import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/testing.dart';
import 'package:mik_data/source/remote/models/business_session.dart';
import 'package:mik_data/utils/fx/business.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/login/screen/mik_account.dart';
import 'package:mik_pages/login/screen/register.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    toastification.dismissAll(delayForAnimation: false);
    Get.reset();
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    testWidgets(
      '$app requires explicit selection when several businesses and branches exist',
      (tester) async {
        BusinessSession? selected;
        final auth = fixtureSession(
          MockClient((request) async {
            if (request.url.path.endsWith('/authorization')) {
              return jsonResponse({
                'businessId': 12345678,
                'membershipId': membership,
                'personnelId': null,
                'scopeType': request.url.queryParameters['scopeType'],
                'scopeId': request.url.queryParameters['scopeId'],
                'allowed': true,
                'permissionCodes': [],
              });
            }
            if (request.url.path.endsWith('/branches')) {
              return jsonResponse({
                'items': [
                  fixtureResult()['branch'],
                  {
                    ...fixtureResult()['branch'] as Map,
                    'branchId': 'second-branch',
                    'name': 'شعبه دوم',
                  },
                ],
                'nextCursor': null,
              });
            }
            return jsonResponse({
              'items': [
                {
                  'businessId': 12345678,
                  'name': 'فروشگاه اول',
                  'membershipId': membership,
                  'membershipType': app == 'mik' ? 'OWNER' : 'PERSONNEL',
                },
                {
                  'businessId': 87654321,
                  'name': 'فروشگاه دوم',
                  'membershipId': 'other-member',
                  'membershipType': 'PERSONNEL',
                },
              ],
              'nextCursor': null,
            });
          }),
          appId: app,
        );
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              home: MikAccountScreen(
                session: auth,
                business: BusinessFX(
                  session: auth,
                  store: MemoryOnboardingStore(),
                ),
                onLogout: () async {},
                onSelected: (value) async {
                  selected = value;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('انتخاب کسب‌وکار'), findsOneWidget);
        expect(selected, isNull);
        await tester.tap(find.text('فروشگاه اول'));
        await tester.pumpAndSettle();
        expect(find.text('انتخاب شعبه'), findsOneWidget);
        expect(selected, isNull);
        await tester.tap(find.text('شعبه دوم'));
        await tester.pumpAndSettle();
        expect(selected?.business.businessId, 12345678);
        expect(
          BusinessContext.forApp(app)?.selectedBranch?.branchId,
          'second-branch',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('$app no accessible branch cannot open the destination', (
      tester,
    ) async {
      var selected = false;
      final auth = fixtureSession(
        MockClient((request) async {
          if (request.url.path.endsWith('/authorization')) {
            return jsonResponse({
              'businessId': 12345678,
              'membershipId': membership,
              'personnelId': null,
              'scopeType': 'BUSINESS',
              'scopeId': '12345678',
              'allowed': true,
              'permissionCodes': [],
            });
          }
          return jsonResponse({
            'items': request.url.path.endsWith('/branches')
                ? []
                : [
                    {
                      'businessId': 12345678,
                      'name': 'فروشگاه',
                      'membershipId': membership,
                      'membershipType': 'PERSONNEL',
                    },
                  ],
            'nextCursor': null,
          });
        }),
        appId: app,
      );
      await tester.pumpWidget(
        GetMaterialApp(
          home: MikAccountScreen(
            session: auth,
            business: BusinessFX(session: auth, store: MemoryOnboardingStore()),
            onLogout: () async {},
            onSelected: (_) async {
              selected = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('شعبهٔ فعال و قابل دسترسی وجود ندارد.'), findsOneWidget);
      expect(selected, isFalse);
      expect(BusinessContext.forApp(app)?.selectedBranch, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('MikYar without memberships cannot register an owner business', (
    tester,
  ) async {
    final auth = fixtureSession(
      MockClient((_) async => jsonResponse({'items': [], 'nextCursor': null})),
      appId: 'mikyar',
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: MikAccountScreen(session: auth, onLogout: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('عضویت فعال در هیچ کسب‌وکاری ندارید.'), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
