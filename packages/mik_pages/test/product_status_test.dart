import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_pages/product/detail/controller.dart';
import 'package:mik_pages/product/detail/screen.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_detail_fixtures.dart';

class StatusServer extends DetailServer {
  StatusServer(super.app) {
    permissions.addAll(['pim.product.update', 'pim.product.archive']);
  }
  final value = {...fixturePim(PimResource.products), 'status': 'DRAFT'};
  @override
  Map<String, dynamic> get product => value;
  String? rejection;
  bool loseReply = false;
  final replies = <String, http.Response>{};
  List<http.Request> get changes =>
      requests.where((r) => r.method == 'PATCH').toList();
  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.method != 'PATCH') return super.respond(request);
    requests.add(request);
    final key = request.headers['idempotency-key']!;
    if (replies.containsKey(key)) return replies[key]!;
    if (rejection != null) {
      return jsonResponse({
        'error': {'code': rejection},
      }, rejection == 'REVISION_CONFLICT' ? 409 : 400);
    }
    final body = jsonDecode(request.body) as Map;
    if (body['expectedRevision'] != value['revision']) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    value['status'] = body['status'];
    value['revision'] = (value['revision'] as int) + 1;
    final response = jsonResponse({
      'businessId': 12345678,
      'replayed': false,
      'item': value,
    });
    replies[key] = response;
    if (loseReply) {
      return jsonResponse({
        'error': {'code': 'UNAVAILABLE', 'retryable': true},
      }, 503);
    }
    return response;
  }

  ProductDetailController controller() => ProductDetailController(
    appId: app,
    businessId: 12345678,
    productId: productId,
  );
}

void main() {
  setUpAll(() async {
    var root = Directory.current;
    while (!File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
            .existsSync() &&
        root.parent.path != root.path) {
      root = root.parent;
    }
    await (FontLoader('ravi')..addFont(
          File('${root.path}/mik-app/assets/fonts/RaviLight.ttf')
              .readAsBytes()
              .then((b) => ByteData.sublistView(b)),
        ))
        .load();
  });
  setUp(resetOnboardingStorage);
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app status transitions use revision and independent archive permission',
      () async {
        final s = StatusServer(app)..activate();
        final c = s.controller();
        await c.load();
        await c.changeStatus('ACTIVE');
        expect(c.product.value!.status, 'ACTIVE');
        expect(jsonDecode(s.changes.single.body), {
          'status': 'ACTIVE',
          'expectedRevision': 3,
        });
        await c.changeStatus('DRAFT');
        await c.changeStatus('ARCHIVED');
        expect(c.product.value!.status, 'ARCHIVED');
        expect(c.canStatus('ACTIVE'), isFalse);
        await c.changeStatus('ACTIVE');
        expect(s.changes, hasLength(3));
        await c.changeStatus('DRAFT');
        expect(c.product.value!.status, 'DRAFT');
        s.permissions.remove('pim.product.update');
        await c.load();
        expect(c.canStatus('ACTIVE'), isFalse);
        expect(c.canStatus('ARCHIVED'), isTrue);
        await c.changeStatus('ARCHIVED');
        expect(c.canStatus('DRAFT'), isFalse);
        expect(
          s.changes.every(
            (r) =>
                r.headers['x-app-id'] == app &&
                r.url.path.endsWith('/products/$productId'),
          ),
          isTrue,
        );
        c.onClose();
      },
    );
    test(
      '$app server rejection and revision conflict keep actual status',
      () async {
        final s = StatusServer(app)..activate();
        final c = s.controller();
        await c.load();
        s.rejection = 'VALIDATION_FAILED';
        await c.changeStatus('ACTIVE');
        expect(c.product.value!.status, 'DRAFT');
        expect(c.statusError.value, contains('قیمت پیش‌فرض'));
        expect(c.pendingStatus.value, isNull);
        s.rejection = 'REVISION_CONFLICT';
        await c.changeStatus('ACTIVE');
        expect(c.statusConflict.value, isTrue);
        await c.changeStatus('ARCHIVED');
        expect(s.changes, hasLength(2));
        s.rejection = null;
        await c.load();
        expect(c.statusConflict.value, isFalse);
        BusinessContext.clear(app);
        await c.changeStatus('ACTIVE');
        expect(s.changes, hasLength(2));
        c.onClose();
      },
    );
    test(
      '$app uncertain change reopens and replays original revision and key',
      () async {
        final s = StatusServer(app)..loseReply = true;
        s.activate();
        var c = s.controller();
        await c.load();
        await c.changeStatus('ACTIVE');
        expect(c.pendingHere, isTrue);
        expect(c.product.value!.status, 'DRAFT');
        c.onClose();
        c = s.controller();
        await c.load();
        expect(c.product.value!.status, 'ACTIVE');
        expect(c.pendingHere, isTrue);
        await c.changeStatus('ARCHIVED');
        expect(s.changes, hasLength(1));
        await c.changeStatus('ACTIVE');
        expect(c.pendingStatus.value, isNull);
        expect(s.changes, hasLength(2));
        expect(s.changes.first.body, s.changes.last.body);
        expect(
          s.changes.first.headers['idempotency-key'],
          s.changes.last.headers['idempotency-key'],
        );
        c.onClose();
      },
    );
    testWidgets(
      '$app confirms activation archive and draft restoration in existing details',
      (tester) async {
        final s = StatusServer(app)..activate();
        await tester.pumpWidget(
          GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: ProductDetailScreen(
              appId: app,
              businessId: 12345678,
              productId: productId,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('مشخصات'));
        await tester.pumpAndSettle();
        for (final action in [
          'فعال‌سازی محصول',
          'آرشیو محصول',
          'بازگردانی به پیش‌نویس',
        ]) {
          await tester.ensureVisible(find.text(action));
          await tester.pumpAndSettle();
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          final before = s.changes.length;
          expect(find.text(action), findsNWidgets(2));
          await tester.tap(find.text(action).last);
          await tester.pumpAndSettle();
          expect(s.changes, hasLength(before + 1));
          if (action == 'آرشیو محصول') {
            expect(find.text('فعال‌سازی محصول'), findsNothing);
          }
        }
        expect(s.value['status'], 'DRAFT');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
