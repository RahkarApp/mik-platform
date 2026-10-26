import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_components/elements/input/imageSelector.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/media_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/product_media_test.dart' as media;
import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

void main() {
  setUp(resetOnboardingStorage);
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    testWidgets(
      '$app native image selector uploads, completes and binds the image to its product',
      (tester) async {
        final server = media.MediaServer(app);
        final writes = <http.Request>[];
        final fx = pimFixture(
          MockClient((request) async {
            if (request.url.path.endsWith('/authorization')) {
              return jsonResponse(
                fixtureAuthorization([
                  'pim.product.read',
                  'pim.product.update',
                  'pim.product.shop.update',
                  'media.file.read',
                  'media.file.upload',
                ]),
              );
            }
            if (request.url.path.endsWith('/products/$productId')) {
              final row = fixturePim(PimResource.products);
              if (request.method == 'PATCH') {
                writes.add(request);
                return jsonResponse({
                  'businessId': 12345678,
                  'replayed': false,
                  'item': {
                    ...row,
                    ...jsonDecode(request.body) as Map,
                    'revision': (row['revision'] as int) + 1,
                  },
                });
              }
              return jsonResponse({'businessId': 12345678, 'item': row});
            }
            return server.respond(request);
          }),
          appId: app,
        );
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ProductMediaScreen(fx: fx, productId: productId),
                      ),
                    ),
                    child: const Text('تصاویر'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('تصاویر'));
        await tester.pumpAndSettle();
        final selector = tester.widget<ImageSelector>(
          find.byType(ImageSelector),
        );
        expect(selector.remote, isTrue);
        selector.imgSelectName.assignAll(<String>['image.png']);
        selector.imgSelectBytes.assignAll([media.imageBytes]);
        selector.callback(
          ['image.png'],
          selector.imgSelectName,
          selector.imgSelectBytes,
        );
        await tester.tap(find.text('ثبت تصاویر'));
        await tester.pumpAndSettle();
        expect(server.puts, 1);
        expect(writes, hasLength(1));
        expect(jsonDecode(writes.single.body)['media'], [
          {'mediaId': media.mediaId, 'sortOrder': 0},
        ]);
        expect(find.byType(ProductMediaScreen), findsNothing);
        expect(find.text('تصاویر محصول با موفقیت ثبت شد.'), findsOneWidget);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
