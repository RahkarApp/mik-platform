import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/invoice_change.dart';
import 'package:mik_pages/invoice/change_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import 'invoice_change_test.dart' as previous;

class DeliveryServer extends previous.ChangeServer {
  DeliveryServer(super.app) {
    posted = false;
  }
  String delivery = 'PENDING';
  bool statusAllowed = true, creditDisabled = false, missingPosting = false;
  int stockPosts = 0;
  @override
  Map<String, Object?> detail(String type) => {
    ...super.detail(type),
    'deliveryStatus': delivery,
  };
  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (statusAllowed) {
        (json['permissionCodes'] as List).addAll([
          'accounting.sale.status.ready',
          'accounting.sale.status.shipped',
          'accounting.sale.status.delivered',
        ]);
      }
      return jsonResponse(json);
    }
    if (request.method == 'POST' &&
        request.url.path.endsWith('/invoices/status')) {
      final key = request.headers['idempotency-key']!;
      if (!receipts.containsKey(key)) {
        final body = jsonDecode(request.body) as Map;
        expect(body.keys.toSet(), {
          'invoiceId',
          'expectedRevision',
          'status',
          'reason',
        });
        if (creditDisabled) {
          return jsonResponse({
            'error': {'code': 'CREDIT_SALES_DISABLED'},
          }, 409);
        }
        finished = false;
      }
    }
    return super.respond(request);
  }

  @override
  void complete() {
    if (action != 'status') {
      super.complete();
      return;
    }
    if (finished) return;
    finished = true;
    revision++;
    delivery = command!['status'] as String;
    if (['SHIPPED', 'DELIVERED'].contains(delivery) &&
        !posted &&
        !missingPosting) {
      posted = true;
      stockPosts++;
    }
  }

  InvoiceChangeCommand status(String value) =>
      InvoiceChangeCommand('status', {...body, 'status': value});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var dir = Directory.current;
    while (!File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      dir = dir.parent;
    }
    await (FontLoader('ravi')..addFont(
          File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  });
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app delivery exact replay and one dispatch for shipped then delivered',
      () async {
        final server = DeliveryServer(app);
        var fx = await server.client();
        var row = await fx.load();
        expect(fx.canDeliver(row, 'PENDING'), isFalse);
        expect(fx.canDeliver(row, 'READY'), isTrue);
        server.lost = true;
        await expectLater(fx.send(server.status('READY')), throwsA(anything));
        final saved = fx.pending!;
        fx = InvoiceChangeFX(fx.context, server.row);
        await fx.restore();
        await fx.send(fx.pending!);
        await fx.refresh();
        row = await fx.finish();
        expect(row.detail.summary.deliveryStatus, 'READY');
        expect(server.stockPosts, 0);
        expect(fx.canDeliver(row, 'PENDING'), isTrue);
        expect(
          server.mutationRequests.first.body,
          server.mutationRequests.last.body,
        );
        expect(
          server.mutationRequests.last.headers['idempotency-key'],
          saved.key,
        );
        for (final status in ['SHIPPED', 'DELIVERED']) {
          await fx.send(server.status(status));
          await fx.refresh();
          row = await fx.finish();
          expect(row.detail.summary.deliveryStatus, status);
          expect(server.stockPosts, 1);
          expect(fx.canDeliver(row, 'PENDING'), isFalse);
          expect(fx.canDeliver(row, 'READY'), isFalse);
        }
        expect(fx.canDeliver(row, 'SHIPPED'), isFalse);
      },
    );
    test(
      '$app delivery permission, credit, revision and physical confirmation response',
      () async {
        final server = DeliveryServer(app);
        final fx = await server.client();
        await fx.load();
        server.statusAllowed = false;
        await expectLater(
          fx.send(server.status('SHIPPED')),
          throwsA(isA<AuthError>().having((e) => e.code, 'code', 'FORBIDDEN')),
        );
        expect(server.mutationRequests, isEmpty);
        server.statusAllowed = true;
        server.creditDisabled = true;
        await expectLater(
          fx.send(server.status('SHIPPED')),
          throwsA(
            isA<AuthError>().having(
              (e) => e.code,
              'code',
              'CREDIT_SALES_DISABLED',
            ),
          ),
        );
        expect(fx.pending, isNull);
        server.creditDisabled = false;
        server.conflict = true;
        await expectLater(
          fx.send(server.status('READY')),
          throwsA(
            isA<AuthError>().having((e) => e.code, 'code', 'REVISION_CONFLICT'),
          ),
        );
        server.conflict = false;
        server.missingPosting = true;
        await fx.send(server.status('DELIVERED'));
        await fx.refresh();
        await expectLater(fx.finish(), throwsFormatException);
        expect(fx.pending, isNotNull);
        server.posted = true;
        expect((await fx.finish()).detail.summary.deliveryStatus, 'DELIVERED');
      },
    );
    testWidgets(
      '$app delivery submits without a separate physical confirmation toggle',
      (tester) async {
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 800, 1300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = DeliveryServer(app);
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: InvoiceChangeScreen(
                appId: app,
                invoice: server.row,
                delivery: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('ارسال‌شده'));
        final field = find.descendant(
          of: find.byKey(const ValueKey('invoice-change-reason')),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, 'خروج واقعی کالا و تحویل به پیک');
        final submit = find.text('ثبت تحویل فاکتور');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        expect(find.text('بله'), findsNothing);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(server.delivery, 'SHIPPED');
        expect(server.stockPosts, 1);
        expect(find.text('عملیات فاکتور با موفقیت تکمیل شد.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
