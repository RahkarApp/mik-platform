import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/invoice_payment.dart';
import 'package:mik_pages/invoice/change_screen.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_pages/invoice/payment_screen.dart';
import 'package:toastification/toastification.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'invoice_payment_test.dart' as payment;
import 'invoice_change_test.dart' as change;
import 'invoice_read_test.dart' show invoiceOne, partyId;

const newVariant = '11111111-1111-4111-8111-111111111117';

class RefundServer extends payment.PaymentServer {
  RefundServer(super.app, {super.type});
  bool refundAllowed = true, anonymous = false;
  @override
  Map<String, dynamic> raw({bool addition = false}) {
    final row = super.raw(addition: addition);
    return {
      ...row,
      'partySnapshot': {...row['partySnapshot'] as Map, 'isDefault': anonymous},
    };
  }

  void seed() {
    sourceRows.add({
      'businessId': 12345678,
      'sourceId': payment.sourceId,
      'partyId': partyId,
      'partyType': partyType,
      'kind': 'CREDIT_NOTE',
      'referenceId': invoiceOne,
      'status': 'ACTIVE',
      'amount': 40,
      'usedAmount': 0,
      if (anonymous) 'restrictedRootInvoiceId': invoiceOne,
    });
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/authorization')) {
      final response = await super.respond(request);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (refundAllowed &&
          request.url.queryParameters['scopeType'] == 'BUSINESS') {
        (json['permissionCodes'] as List).add('accounting.payment.refund');
      }
      return jsonResponse(json);
    }
    if (request.method == 'POST' && request.url.path.endsWith('/v2/payments')) {
      requests.add(request);
      expect(request.headers['x-branch-id'], branch);
      expect(request.headers['x-app-id'], app);
      final key = request.headers['idempotency-key']!;
      if (receipts.containsKey(key)) return jsonResponse(receipts[key]!);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final details = body['payment'] as Map<String, dynamic>;
      expect(details['direction'], direction == 'IN' ? 'OUT' : 'IN');
      expect(details['confirmed'], true);
      if (anonymous) {
        expect(body['rootInvoiceId'], invoiceOne);
      } else {
        expect(body.containsKey('rootInvoiceId'), false);
      }
      final amount = details['amount'] as int;
      if (amount > 40 - (sourceRows.single['usedAmount'] as int)) {
        return jsonResponse({
          'error': {'code': 'INSUFFICIENT_CREDIT'},
        }, 409);
      }
      sourceRows.single['usedAmount'] =
          (sourceRows.single['usedAmount'] as int) + amount;
      final row = <String, dynamic>{
        ...details,
        'businessId': 12345678,
        'branchId': branch,
        'partyId': partyId,
        'partyType': partyType,
        'paymentId': payment.paymentId,
        'status': 'CONFIRMED',
        'purpose': 'REFUND',
        'financialVersion': 2,
        'revision': 1,
      }..remove('confirmed');
      paymentRows.add(row);
      final result = {'businessId': 12345678, 'payment': row};
      receipts[key] = result;
      if (lose) {
        lose = false;
        throw TimeoutException('lost refund reply');
      }
      return jsonResponse(result);
    }
    return super.respond(request);
  }

  InvoicePaymentCommand refund(int amount) => InvoicePaymentCommand('REFUND', {
    'partyId': partyId,
    'partyType': partyType,
    if (anonymous) 'rootInvoiceId': invoiceOne,
    'payment': {
      'amount': amount,
      'method': 'CASH',
      'direction': direction == 'IN' ? 'OUT' : 'IN',
      'confirmed': true,
      'routing': {'fundId': payment.fundId},
    },
  });
}

class PickerServer extends change.ChangeServer {
  PickerServer(super.app, {super.documentType});
  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      final reply = await super.respond(request);
      final json = jsonDecode(reply.body) as Map<String, dynamic>;
      (json['permissionCodes'] as List).addAll([
        'pim.product.read',
        'pim.variant.read',
        'pim.price.read',
        'business.branch.read',
        'business.warehouse.read',
      ]);
      return jsonResponse(json);
    }
    if (path.contains('/pim/')) {
      requests.add(request);
      if (path.endsWith('/products')) {
        return jsonResponse(fixturePimPage(PimResource.products));
      }
      if (path.endsWith('/variants')) {
        return jsonResponse(
          fixturePimPage(
            PimResource.variants,
            items: [fixturePim(PimResource.variants, id: newVariant)],
          ),
        );
      }
      if (path.endsWith('/prices')) {
        return jsonResponse(fixturePimPage(PimResource.prices));
      }
      if (path.endsWith('/price')) {
        return jsonResponse({
          'businessId': 12345678,
          'productId': productId,
          'variantId': newVariant,
          'productPriceId': priceId,
          'amount': 100,
          'currency': 'TOMAN',
          'source': 'PRODUCT_BASE',
        });
      }
    }
    if (path.endsWith('/branches/$branch')) {
      return jsonResponse({'item': fixtureResult()['branch']});
    }
    if (path.endsWith('/warehouses')) {
      return jsonResponse({
        'items': [fixtureResult()['warehouse']],
        'nextCursor': null,
      });
    }
    if (path.endsWith('/inventory-access/check')) {
      return jsonResponse({
        'allowed': true,
        'branchId': branch,
        'warehouseId': warehouse,
        'permissionCode': 'inventory.stock.receive',
      });
    }
    return super.respond(request);
  }

  @override
  void complete() {
    if (action != 'amend') {
      super.complete();
      return;
    }
    if (finished) return;
    finished = true;
    revision++;
    total = 200;
  }

  @override
  Map<String, Object?> detail(String type) {
    final row = super.detail(type);
    if (!finished || action != 'amend') return row;
    final view = row['view'] as Map;
    final lines = (command!['lines'] as List)
        .map((r) => {...r as Map, 'name': 'قلم فاکتور', 'amount': 100})
        .toList();
    return {
      ...row,
      'view': {...view, 'lines': lines},
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetOnboardingStorage);
  setUpAll(() async {
    var dir = Directory.current;
    while (!File('${dir.path}/mik-app/assets/fonts/RaviLight.ttf')
        .existsSync()) {
      if (dir.path == dir.parent.path) throw StateError('Workspace not found');
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
    toastification.dismissAll(delayForAnimation: false);
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
    Get.reset();
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app partial refund exact replay, routing, credit and permission',
      () async {
        final server = RefundServer(
          app,
          type: app == 'mik' ? 'SALE' : 'PURCHASE',
        )..seed();
        final context = await server.prepare();
        final fx = InvoicePaymentFX(context, server.summary);
        await fx.authorize();
        expect(
          (await fx.targets('CARD', refund: true)).single.kind,
          server.type == 'SALE' ? 'BANK' : 'TERMINAL',
        );
        server.lose = true;
        await expectLater(
          fx.send(server.refund(20)),
          throwsA(isA<TimeoutException>()),
        );
        final resumed = InvoicePaymentFX(context, server.summary);
        await resumed.send((await resumed.restore())!);
        expect(server.paymentRows, hasLength(1));
        expect((await resumed.sources()).single.available, 20);
        expect(server.writes.first.body, server.writes.last.body);
        expect(
          server.writes.first.headers['idempotency-key'],
          server.writes.last.headers['idempotency-key'],
        );
        await expectLater(
          resumed.send(server.refund(30)),
          throwsA(
            isA<AuthError>().having(
              (e) => e.code,
              'code',
              'INSUFFICIENT_CREDIT',
            ),
          ),
        );
        expect(resumed.pending, isNull);
        server.refundAllowed = false;
        final count = server.writes.length;
        await expectLater(
          resumed.send(server.refund(10)),
          throwsA(isA<AuthError>()),
        );
        expect(server.writes.length, count);
        final anon = RefundServer(app)
          ..anonymous = true
          ..seed();
        final anonFx = InvoicePaymentFX(await anon.prepare(), anon.summary);
        await anonFx.send(anon.refund(10));
        expect(anon.paymentRows.single['purpose'], 'REFUND');
      },
    );
    testWidgets(
      '$app amendment selects a new catalog variant without invoice-create grant',
      (tester) async {
        tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final server = PickerServer(
          app,
          documentType: app == 'mik' ? 'SALE' : 'PURCHASE',
        );
        await server.prepare();
        await tester.pumpWidget(
          ToastificationWrapper(
            child: GetMaterialApp(
              onGenerateRoute: navigation.MikRouter(
                sharedRoutes: SharedRoutes.namedPages,
              ).generateRoute,
              theme: ThemeData(fontFamily: 'ravi'),
              home: InvoiceChangeScreen(appId: app, invoice: server.row),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('افزودن کالای جدید'));
        await tester.pumpAndSettle();
        if (app == 'mikyar') {
          await tester.tap(find.text('انتخاب انبار مقصد'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('invoice-warehouse-$warehouse')),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('پیراهن'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(app == 'mik' ? 'فروش' : 'انتخاب تنوع 1'));
        await tester.pumpAndSettle();
        expect(
          find.text('کالای جدید؛ قبل از ثبت قابل حذف است.'),
          findsOneWidget,
        );
        if (app == 'mikyar') {
          final fields = find
              .byType(TextFormField)
              .evaluate()
              .where((e) => (e.widget as TextFormField).controller?.text == '')
              .toList();
          // Purchase costs are explicitly entered; the blank field isn't filled with a fabricated price.
          expect(fields, isNotEmpty);
          final priceInput = find
              .byWidgetPredicate(
                (w) =>
                    w is Input &&
                    w.name == 'قیمت واحد (تومان)' &&
                    w.controller.text == '',
              )
              .first;
          await tester.ensureVisible(priceInput);
          await tester.enterText(
            find.descendant(
              of: priceInput,
              matching: find.byType(TextFormField),
            ),
            '100',
          );
        }
        final reason = find.byKey(const ValueKey('invoice-change-reason'));
        await tester.ensureVisible(reason);
        await tester.enterText(
          find.descendant(of: reason, matching: find.byType(TextFormField)),
          'افزودن قلم',
        );
        await tester.ensureVisible(find.text('بله'));
        await tester.tap(find.text('بله'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ثبت ویرایش فاکتور'));
        await tester.tap(find.text('ثبت ویرایش فاکتور'));
        await tester.pumpAndSettle();
        expect((server.command!['lines'] as List), hasLength(2));
        final added = (server.command!['lines'] as List).last as Map;
        expect(added['variantId'], newVariant);
        expect(added['warehouseIds'], [warehouse]);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('عملیات فاکتور با موفقیت تکمیل شد.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
    testWidgets('$app partial refund native form consumes only free credit', (
      tester,
    ) async {
      tester.view.physicalSize = Size(app == 'mik' ? 430 : 1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = RefundServer(app, type: app == 'mik' ? 'SALE' : 'PURCHASE')
        ..seed();
      await server.prepare();
      await tester.pumpWidget(
        ToastificationWrapper(
          child: GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: InvoicePaymentScreen(appId: app, invoice: server.summary),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('برگشت وجه'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('صندوق شعبه'));
      await tester.tap(find.text('صندوق شعبه'));
      await tester.pumpAndSettle();
      final amount = find.descendant(
        of: find.byKey(const ValueKey('payment-amount')),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '20');
      await tester.ensureVisible(find.text('بله'));
      await tester.tap(find.text('بله'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ثبت برگشت وجه'));
      await tester.tap(find.text('ثبت برگشت وجه'));
      await tester.pumpAndSettle();
      expect(server.paymentRows.single['amount'], 20);
      expect(server.sourceRows.single['usedAmount'], 20);
      expect(find.text('برگشت جزئی وجه با موفقیت ثبت شد.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
