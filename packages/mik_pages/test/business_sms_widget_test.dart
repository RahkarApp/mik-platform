import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/sms/screen.dart';

import '../../mik_data/test/business_sms_test.dart' as fixture;
import '../../mik_data/test/support/onboarding_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    BusinessContext.clear('mik');
    Get.reset();
  });
  testWidgets(
    'native SMS page loads actual events without invoking legacy APIs or mutations',
    (tester) async {
      fixture.resetStorage();
      final requests = <http.Request>[];
      fixture.activate('mik', (r) async {
        requests.add(r);
        if (r.url.path.endsWith('/authorization')) return fixture.grants(r);
        if (r.url.path.endsWith('/events')) {
          return jsonResponse({
            'events': {
              'SALE_ISSUED': ['customerName'],
            },
            'clubIntegrationActive': false,
          });
        }
        if (r.url.path.endsWith('/wallet')) {
          return jsonResponse({'accounts': []});
        }
        return jsonResponse({'items': [], 'nextCursor': null});
      });
      await tester.pumpWidget(
        GetMaterialApp(
          onGenerateRoute: navigation.MikRouter(
            sharedRoutes: SharedRoutes.namedPages,
          ).generateRoute,
          home: const BusinessSmsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ثبت فروش'), findsOneWidget);
      expect(find.byType(BTN), findsWidgets);
      expect(
        requests.every(
          (r) => r.method == 'GET' && r.url.path.startsWith('/v1/'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
