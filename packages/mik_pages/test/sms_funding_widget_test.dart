import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/business_sms.dart';
import 'package:mik_pages/sms/funding_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/business_sms_test.dart' as fixture;
import '../../mik_data/test/sms_funding_test.dart' as funding;
import '../../mik_data/test/support/onboarding_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    BusinessContext.clear('mik');
    Get.reset();
  });
  testWidgets(
    'native amount input transfers explicit toman amount and opening the page never posts',
    (tester) async {
      fixture.resetStorage();
      final writes = <http.Request>[];
      final context = fixture.activate('mik', (r) async {
        if (r.url.path.endsWith('/authorization')) return funding.grants(r);
        if (r.method == 'GET') {
          return jsonResponse({
            'accounts': [
              funding.accountRow(),
              funding.accountRow(kind: 'SALES'),
            ],
          });
        }
        writes.add(r);
        return jsonResponse({
          'operationId': fixture.templateId,
          'account': funding.accountRow(),
          'replayed': false,
        });
      });
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            home: SmsFundingScreen(sms: BusinessSmsFX(context)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      final input = tester.widget<PriceInput>(find.byType(PriceInput));
      input.controller.text = '۱٬۵۰۰ تومان';
      await tester.tap(find.text('انتقال از کیف فروش'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(writes.single.body, '{"amount":1500}');
      expect(
        find.text('اعتبار از کیف فروش به کیف پیامک منتقل شد.'),
        findsOneWidget,
      );
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
