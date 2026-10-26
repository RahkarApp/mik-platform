import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/pim_group.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/bulk/controller.dart';
import 'package:mik_pages/chatBase/addProduct/addGroupeChat.dart';
import 'package:mik_pages/product/bulk/screen.dart';
import 'package:mik_pages/product/screen/screen.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_add_fixtures.dart';

const secondId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaab';
const brandId = '11111111-1111-4111-8111-111111111119';

class BulkServer extends AddServer {
  BulkServer(super.app) {
    permissions.add('pim.brand.read');
  }
  int? loseCreate;
  bool stopPrice = false, invalidActivation = false;
  final products = <String, Map<String, dynamic>>{};
  final replies = <String, http.Response>{};
  @override
  Future<http.Response> respond(http.Request r) async {
    if (r.method == 'GET' && r.url.path.endsWith('/brands')) {
      requests.add(r);
      return jsonResponse(fixturePimPage(PimResource.brands));
    }
    if (r.method == 'GET') return super.respond(r);
    requests.add(r);
    if (r.url.path.endsWith('/brands')) {
      return jsonResponse({
        'error': {'code': 'UNAVAILABLE', 'retryable': true},
      }, 503);
    }
    final key = r.headers['idempotency-key']!;
    if (replies.containsKey(key)) return replies[key]!;
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    late http.Response result;
    if (r.url.path.endsWith('/products')) {
      final id = products.isEmpty ? productId : secondId;
      final item = {
        ...fixturePim(PimResource.products, id: id, status: 'DRAFT'),
        ...body,
        'revision': 1,
      };
      products[id] = item;
      result = jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'item': item,
        'baseVariant': {...fixturePim(PimResource.variants), 'productId': id},
      });
      replies[key] = result;
      if (products.length == loseCreate) {
        return jsonResponse({
          'error': {'code': 'UNAVAILABLE', 'retryable': true},
        }, 503);
      }
    } else if (r.url.path.endsWith('/prices')) {
      if (stopPrice) {
        return jsonResponse({
          'error': {'code': 'UNAVAILABLE', 'retryable': true},
        }, 503);
      }
      result = jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'item': {...fixturePim(PimResource.prices), ...body},
      });
    } else {
      final id = r.url.pathSegments.last;
      final item = products[id]!;
      expect(body.remove('expectedRevision'), item['revision']);
      products[id] = {
        ...item,
        ...body,
        'revision': (item['revision'] as int) + 1,
      };
      result = jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'item': products[id],
      });
    }
    replies[key] = result;
    if (invalidActivation && r.method == 'PATCH') {
      invalidActivation = false;
      return jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'item': {...products[r.url.pathSegments.last]!, 'status': 'DRAFT'},
      });
    }
    return result;
  }

  ProductBulkController bulk() => ProductBulkController(
    PimGroupFX(
      pimFixture(MockClient(respond), appId: app, store: commands),
      store: store,
    ),
  );
}

void fill(BulkProductRow row, String name, {String price = ''}) {
  row.name = name;
  row.price = price;
  row.categoryIds = [categoryId];
  row.primaryCategoryId = categoryId;
  row.unitId = 1;
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
      '$app final registration requires every price and activates every product after validation',
      () async {
        final s = BulkServer(app);
        final c = s.bulk();
        await c.load();
        expect(c.rows.single.unitId, isNull);
        await c.addRow();
        fill(c.rows.first, 'اول', price: '۰');
        c.rows.first.brandId = brandId;
        fill(c.rows.last, 'دوم');
        c.rows.last.unitId = null;
        expect(await c.save(), isFalse);
        expect(c.rows.last.error.value, isNotNull);
        expect(s.mutations, isEmpty);
        c.rows.last.unitId = 1;
        expect(await c.save(), isFalse);
        expect(s.mutations, isEmpty);
        c.rows.last.price = '120';
        expect(await c.save(), isTrue);
        expect(s.products.values.map((p) => p['status']), ['ACTIVE', 'ACTIVE']);
        expect(s.products[productId]!['brandId'], brandId);
        final price = s.mutations.firstWhere(
          (r) => r.url.path.endsWith('/prices'),
        );
        expect(jsonDecode(price.body)['amount'], 0);
        expect(c.progress(c.rows.first), 'ثبت نهایی انجام شد');
        expect(c.progress(c.rows.last), 'ثبت نهایی انجام شد');
        final count = s.mutations.length;
        expect(await c.save(), isFalse);
        expect(s.mutations.length, count);
        expect(s.requests.every((r) => r.headers['x-app-id'] == app), isTrue);
      },
    );
    test(
      '$app lost create and failed price reopen and resume the same payloads without recreating completed rows',
      () async {
        final s = BulkServer(app)..loseCreate = 2;
        var c = s.bulk();
        await c.load();
        await c.addRow();
        fill(c.rows.first, 'اول', price: '0');
        fill(c.rows.last, 'دوم', price: '120');
        expect(await c.save(), isFalse);
        expect(c.locked, isTrue);
        expect(c.progress(c.rows.first), contains('ثبت قیمت باقی'));
        expect(c.rows.last.error.value, isNotNull);
        final ids = c.rows.map((r) => r.id).toList();
        c = s.bulk();
        await c.load();
        expect(c.rows.map((r) => r.id), ids);
        expect(c.locked, isTrue);
        s.stopPrice = true;
        c.rows.last.name = 'نباید ارسال شود';
        expect(await c.save(), isFalse);
        expect(c.progress(c.rows.first), contains('ثبت قیمت باقی'));
        c = s.bulk();
        await c.load();
        s.stopPrice = false;
        s.invalidActivation = true;
        expect(await c.save(), isFalse);
        expect(c.done.value, isFalse);
        expect(c.state.value.pending, isTrue);
        c = s.bulk();
        await c.load();
        expect(await c.save(), isTrue);
        expect(s.products.values.every((p) => p['status'] == 'ACTIVE'), isTrue);
        final activations = s.mutations
            .where((r) => r.method == 'PATCH')
            .toList();
        expect(activations, hasLength(3));
        expect(
          activations[0].headers['idempotency-key'],
          activations[1].headers['idempotency-key'],
        );
        final creates = s.mutations
            .where((r) => r.url.path.endsWith('/products'))
            .toList();
        expect(creates, hasLength(3));
        expect(s.products, hasLength(2));
        expect(creates[1].body, creates[2].body);
        expect(
          creates[1].headers['idempotency-key'],
          creates[2].headers['idempotency-key'],
        );
        final prices = s.mutations
            .where((r) => r.url.path.endsWith('/prices'))
            .toList();
        expect(prices, hasLength(3));
        expect(prices[0].body, prices[1].body);
        expect(
          prices[0].headers['idempotency-key'],
          prices[1].headers['idempotency-key'],
        );
        expect(s.products[secondId]!['name'], 'دوم');
        expect((await c.group.read()).drafts, isEmpty);
      },
    );
    test(
      '$app local drafts retain real IDs and invalid price input; permission and foreign pending commands block submission',
      () async {
        final s = BulkServer(app);
        var c = s.bulk();
        await c.load();
        fill(c.rows.single, 'پیش‌نویس', price: '12.5');
        c.rows.single.brandId = brandId;
        final id = c.rows.single.id;
        await c.persist();
        c = s.bulk();
        await c.load();
        expect(c.rows.single.id, id);
        expect(c.rows.single.price, '12.5');
        expect(c.rows.single.categoryIds, [categoryId]);
        expect(c.rows.single.brandId, brandId);
        expect(await c.save(), isFalse);
        expect(s.mutations, isEmpty);
        s.permissions.remove('pim.price.create');
        c = s.bulk();
        await c.load();
        c.rows.single.price = '1';
        expect(await c.save(), isFalse);
        expect(s.mutations, isEmpty);
        c.rows.single.price = '';
        expect(await c.save(), isFalse);
        expect(s.mutations, isEmpty);
        s.permissions.add('pim.price.create');
        s.permissions.remove('pim.product.update');
        c = s.bulk();
        await c.load();
        c.rows.single.price = '1';
        expect(await c.save(), isFalse);
        expect(s.mutations, isEmpty);
        s.permissions.add('pim.product.update');
        c = s.bulk();
        await c.load();
        c.rows.single.price = '1';
        expect(await c.save(), isTrue);
        final blocked = BulkServer(app)..permissions.add('pim.brand.create');
        var d = blocked.bulk();
        await d.load();
        final pending = d.group.products.change(PimResource.brands, {
          'name': 'برند',
        });
        await expectLater(
          d.group.products.execute(pending),
          throwsA(isA<AuthError>()),
        );
        final before = blocked.mutations.length;
        d = blocked.bulk();
        await d.load();
        expect(d.locked, isTrue);
        expect(d.state.value.pending, isFalse);
        expect(await d.save(), isFalse);
        expect(blocked.mutations.length, before);
        expect(
          blocked.commands.values.values.single.idempotencyKey,
          pending.idempotencyKey,
        );
      },
    );
    test(
      '$app chat names persist by ID, reject duplicates, rename and delete without API mutations',
      () async {
        final s = BulkServer(app);
        var chat = ProductGroupAddController(s.bulk());
        await chat.load();
        expect(chat.products, isEmpty);
        await chat.addProduct('کیف ۱۲');
        final row = chat.bulk.rows.single;
        fill(row, row.name);
        row.brandId = brandId;
        await chat.bulk.persist();
        await chat.addProduct(' کیف12 ');
        expect(chat.bulk.rows, hasLength(1));
        expect(chat.chatMessages.last.isDuplicate, isTrue);
        chat.editingId = row.id;
        chat.editingProductName = row.name;
        chat.previousInputText = 'متن قبلی';
        await chat.addProduct('کیف جدید');
        expect(chat.bulk.rows.single.id, row.id);
        expect(chat.bulk.rows.single.categoryIds, [categoryId]);
        expect(chat.bulk.rows.single.brandId, brandId);
        expect(chat.inputController.text, 'متن قبلی');
        await chat.addProduct('دوم');
        chat.onClose();
        chat = ProductGroupAddController(s.bulk());
        await chat.load();
        expect(chat.hasPendingProducts.value, isTrue);
        expect(chat.products, ['کیف جدید', 'دوم']);
        expect(chat.bulk.rows.first.id, row.id);
        chat.confirmPendingProducts();
        await chat.removeProductByName('دوم', rowId: chat.bulk.rows.last.id);
        expect(chat.products, ['کیف جدید']);
        chat.clearAllProducts();
        await chat.confirmDeleteAll();
        expect((await chat.bulk.group.read()).drafts, isEmpty);
        expect(s.mutations, isEmpty);
        chat.onClose();
      },
    );
    testWidgets(
      '$app chat pending registration cannot be deleted and resumes saved requests',
      (tester) async {
        final s = BulkServer(app)..loseCreate = 2;
        final bulk = s.bulk();
        await bulk.load();
        await bulk.addRow();
        fill(bulk.rows.first, 'اول', price: '0');
        fill(bulk.rows.last, 'دوم', price: '120');
        expect(await bulk.save(), isFalse);
        final restored = s.bulk();
        await tester.pumpWidget(
          GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: Scaffold(
              body: Builder(
                builder: (context) => BTN(
                  name: 'بازکردن چت',
                  navigate: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductGroupAddScreen(
                        context: restored.group.products.context,
                        controller: restored,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('بازکردن چت'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductGroupAddScreen), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.text('حذف همه'), findsNothing);
        await tester.tap(find.text('ادامهٔ ثبت قبلی'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductBulkScreen), findsOneWidget);
        await tester.tap(find.text('ادامهٔ ثبت قبلی'));
        await tester.pumpAndSettle();
        expect(s.products, hasLength(2));
        final creates = s.mutations
            .where((r) => r.url.path.endsWith('/products'))
            .toList();
        expect(creates, hasLength(3));
        expect(
          creates[1].headers['idempotency-key'],
          creates[2].headers['idempotency-key'],
        );
        await tester.tap(find.text('بازگشت به محصولات'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductGroupAddScreen), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        bulk.onClose();
      },
    );
    testWidgets(
      '$app product menu opens shared bulk form with native inputs and submits two persisted rows',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final s = BulkServer(app);
        final fx = pimFixture(MockClient(s.respond), appId: app);
        final shared = PimFX.forContext(fx.context);
        final group = PimGroupFX.forProducts(shared);
        await group.remember([
          for (final name in ['اول', 'دوم'])
            BulkProductRow(
              name: name,
              price: name == 'دوم' ? '120' : '',
              categoryIds: [categoryId],
              primaryCategoryId: categoryId,
              unitId: 1,
            ).toDraft(),
        ]);
        productDashboardController.search.value = '';
        await tester.pumpWidget(
          GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: Scaffold(body: ProductTabDashboard(appId: app)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('محصول جدید'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('افزودن گروهی'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductGroupAddScreen), findsOneWidget);
        expect(find.byType(ProductBulkScreen), findsNothing);
        await tester.tap(find.text('تکمیل اطلاعات و ثبت').last);
        await tester.pumpAndSettle();
        expect(find.byType(ProductBulkScreen), findsOneWidget);
        expect(find.text('افزودن ردیف'), findsNothing);
        expect(find.byType(Input), findsWidgets);
        expect(find.byType(PriceInput), findsWidgets);
        final nameInput = find
            .byWidgetPredicate((w) => w is Input && w.name == 'نام محصول')
            .first;
        await tester.enterText(
          find.descendant(of: nameInput, matching: find.byType(TextField)),
          'اول از فرم',
        );
        final priceInput = find.byType(PriceInput).first;
        await tester.ensureVisible(priceInput);
        await tester.enterText(
          find.descendant(of: priceInput, matching: find.byType(TextField)),
          '0',
        );
        await tester.pumpAndSettle();
        final submit = find.byWidgetPredicate(
          (w) => w is BTN && w.name == 'ثبت نهایی محصولات',
        );
        await tester.scrollUntilVisible(
          submit,
          200,
          scrollable: find
              .descendant(
                of: find.byType(ProductBulkScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.text('ثبت نهایی محصولات'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ثبت نهایی محصولات'));
        await tester.pumpAndSettle();
        expect(find.text('ثبت نهایی انجام شد'), findsNWidgets(2));
        expect(s.products, hasLength(2));
        expect(s.products[productId]!['name'], 'اول از فرم');
        expect(s.products[productId]!['status'], 'ACTIVE');
        expect(s.products[secondId]!['status'], 'ACTIVE');
        await tester.tap(find.text('بازگشت به محصولات'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductBulkScreen), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
