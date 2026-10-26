import 'dart:async';

import 'package:toastification/toastification.dart';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/screen/screen.dart';
import 'package:mik_pages/product/screen/tabs/controllers/product.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    var root = Directory.current;
    while (!File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
            .existsSync() &&
        root.parent.path != root.path) {
      root = root.parent;
    }
    final font = FontLoader('ravi')
      ..addFont(
        File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    await font.load();
  });
  setUp(() {
    productDashboardController.search.value = '';
    productDashboardController.index.value = 0;
  });
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    testWidgets(
      '$app displays server records in the existing row with unknown price and stock',
      (tester) async {
        pimFixture(
          MockClient(
            (request) async => request.url.path.endsWith('/authorization')
                ? jsonResponse(fixtureAuthorization(['pim.product.read']))
                : jsonResponse(fixturePimPage(PimResource.products)),
          ),
          appId: app,
        );
        final c = ProductTabDashboardController();
        await tester.pumpWidget(
          GetMaterialApp(
            theme: ThemeData(fontFamily: 'ravi'),
            home: Scaffold(
              body: ProductTabDashboard(appId: app, controller: c),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PimProductItem), findsOneWidget);
        expect(find.text('پیراهن'), findsOneWidget);
        expect(find.text('قابل فروش: —'), findsOneWidget);
        expect(find.text('قیمت: —'), findsOneWidget);
        expect(find.text('بدون موجودی'), findsNothing);
        expect(find.text('هیچ محصولی وجود ندارد!'), findsNothing);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(c.prd, isEmpty);
      },
    );

    testWidgets(
      '$app shows loading, distinguishes errors from empty lists and retries',
      (tester) async {
        final response = Completer<http.Response>();
        var retry = false;
        pimFixture(
          MockClient((request) async {
            if (request.url.path.endsWith('/authorization')) {
              return jsonResponse(fixtureAuthorization(['pim.product.read']));
            }
            if (!retry) return response.future;
            return jsonResponse(
              fixturePimPage(PimResource.products, items: []),
            );
          }),
          appId: app,
        );
        final c = ProductTabDashboardController();
        await tester.pumpWidget(
          GetMaterialApp(
            theme: ThemeData(fontFamily: 'ravi'),
            home: Scaffold(
              body: ProductTabDashboard(appId: app, controller: c),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        response.complete(
          jsonResponse({
            'error': {'code': 'FORBIDDEN'},
          }, 403),
        );
        await tester.pumpAndSettle();
        expect(find.text('هیچ محصولی وجود ندارد!'), findsNothing);
        expect(find.text('تلاش مجدد'), findsOneWidget);
        retry = true;
        await tester.tap(find.text('تلاش مجدد'));
        await tester.pumpAndSettle();
        expect(find.text('هیچ محصولی وجود ندارد!'), findsOneWidget);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'unsupported filter tabs are disabled while status remains usable',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      pimFixture(
        MockClient(
          (request) async => request.url.path.endsWith('/authorization')
              ? jsonResponse(fixtureAuthorization(['pim.product.read']))
              : jsonResponse(fixturePimPage(PimResource.products, items: [])),
        ),
      );
      final c = ProductTabDashboardController();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData(fontFamily: 'ravi'),
          home: Scaffold(body: ProductTabDashboard(controller: c)),
        ),
      );
      await tester.pumpAndSettle();
      c.filter(tester.element(find.byType(ProductTabDashboard)));
      await tester.pumpAndSettle();
      final type = tester.widget<MyTab>(find.byType(MyTab).first);
      final status = tester.widget<MyTab>(find.byType(MyTab).last);
      expect(type.enabledValues, {'همه'});
      expect(status.enabledValues, {'همه', 'فعال', 'پیش‌نویس', 'آرشیو'});
      await tester.tap(find.text('موجود'));
      await tester.pump();
      expect(c.typeFilter.value, 'فعال');
      expect(
        tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged,
        isNull,
      );
      expect(tester.takeException(), isNull);
      Get.back();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('scanner is disabled only when the host requests it', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData(fontFamily: 'ravi'),
        home: Scaffold(
          body: MySearchBar(
            type: SearchBarType.product,
            enableScanner: false,
            callback: (_) =>
                fail('Unavailable scanner must not submit a barcode'),
          ),
        ),
      ),
    );
    final taps = tester.widgetList<InkWell>(find.byType(InkWell));
    expect(taps.any((widget) => widget.onTap == null), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
