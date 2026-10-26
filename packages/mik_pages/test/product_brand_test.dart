import 'package:mik_router/mik_router.dart' as navigation;
import 'package:mik_pages/routing/shared_routes.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/buttons/button.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_pages/product/screen/screen.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_pages/product/brand/controller.dart';
import 'package:mik_pages/product/brand/screen.dart';
import 'package:mik_pages/product/edit/screen.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_add_fixtures.dart';
import 'support/product_edit_fixtures.dart';

const brandId = '11111111-1111-4111-8111-111111111119';

class BrandServer {
  final String app;
  BrandServer(this.app);
  final store = MemoryPimStore();
  final requests = <http.Request>[];
  final permissions = [
    'pim.brand.read',
    'pim.brand.create',
    'pim.brand.update',
    'pim.brand.delete',
  ];
  Map<String, dynamic> brand = {
    ...fixturePim(PimResource.brands),
    'website': 'https://example.com',
  };
  bool inUse = false, conflict = false, lost = false;
  final results = <String, http.Response>{};
  List<http.Request> get mutations =>
      requests.where((v) => v.method != 'GET').toList();
  Future<http.Response> respond(http.Request r) async {
    requests.add(r);
    if (r.url.path.endsWith('/authorization')) {
      return jsonResponse(fixtureAuthorization(permissions));
    }
    if (r.method == 'GET' && r.url.path.endsWith('/products')) {
      return jsonResponse(fixturePimPage(PimResource.products));
    }
    if (r.method == 'GET') {
      return jsonResponse(fixturePimPage(PimResource.brands, items: [brand]));
    }
    final key = r.headers['idempotency-key']!;
    if (results.containsKey(key)) return results[key]!;
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (conflict) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    if (inUse && body['status'] == 'ARCHIVED') {
      return jsonResponse({
        'error': {'code': 'RECORD_IN_USE'},
      }, 409);
    }
    if (r.method == 'PATCH') {
      expect(body.remove('expectedRevision'), brand['revision']);
    }
    brand = {...brand, ...body, 'revision': (brand['revision'] as int) + 1};
    final result = jsonResponse({
      'businessId': 12345678,
      'replayed': false,
      'item': brand,
    });
    results[key] = result;
    return lost
        ? jsonResponse({
            'error': {'code': 'UNAVAILABLE', 'retryable': true},
          }, 503)
        : result;
  }

  PimFX client() => pimFixture(MockClient(respond), appId: app, store: store);
  Future<ProductBrandController> ready() async {
    final c = ProductBrandController();
    await c.attachClient(client());
    return c;
  }
}

class BrandAddServer extends AddServer {
  BrandAddServer(super.app) {
    permissions.add('pim.brand.read');
  }
  @override
  Future<http.Response> respond(http.Request r) async {
    if (r.method == 'GET' && r.url.path.endsWith('/brands')) {
      requests.add(r);
      return jsonResponse(fixturePimPage(PimResource.brands));
    }
    return super.respond(r);
  }
}

class BrandEditServer extends EditServer {
  BrandEditServer(super.app) {
    permissions.add('pim.brand.read');
    product['brandId'] = brandId;
  }
  bool failBrands = false;
  @override
  Future<http.Response> respond(http.Request r) async {
    if (r.method == 'GET' && r.url.path.endsWith('/brands')) {
      requests.add(r);
      return failBrands
          ? jsonResponse({
              'error': {'code': 'UNAVAILABLE'},
            }, 503)
          : jsonResponse(fixturePimPage(PimResource.brands));
    }
    return super.respond(r);
  }
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
      '$app brand validation, create, nullable edit, archive in-use and revision conflict',
      () async {
        final s = BrandServer(app);
        final c = await s.ready();
        expect(
          await c.save(name: 'برند', website: 'https://user:pass@example.com'),
          isFalse,
        );
        expect(s.mutations, isEmpty);
        expect(
          await c.save(
            name: ' برند تازه ',
            latinName: ' Brand ',
            website: 'https://example.org',
          ),
          isTrue,
        );
        expect(jsonDecode(s.mutations.last.body), {
          'name': 'برند تازه',
          'latinName': 'Brand',
          'website': 'https://example.org',
        });
        expect(await c.save(item: c.pro.single, name: 'برند تازه'), isTrue);
        expect(jsonDecode(s.mutations.last.body), {
          'latinName': null,
          'website': null,
          'expectedRevision': 4,
        });
        s.inUse = true;
        await c.changeStatus(c.pro.single);
        expect(c.commandError.value, contains('استفاده شده'));
        expect(c.pending.value, isNull);
        s.inUse = false;
        await c.changeStatus(c.pro.single);
        c.showArchived.value = true;
        expect(c.visible.single.status, 'ARCHIVED');
        await c.changeStatus(c.pro.single);
        expect(c.pro.single.status, 'ACTIVE');
        s.conflict = true;
        expect(await c.save(item: c.pro.single, name: 'تعارض'), isFalse);
        expect(c.conflict.value, isTrue);
        expect(c.canCreate, isFalse);
        s.conflict = false;
        await c.init();
        expect(c.conflict.value, isFalse);
        expect(s.mutations.every((r) => r.headers['x-app-id'] == app), isTrue);
      },
    );
    test(
      '$app uncertain brand request reopens with identical key and permission gates',
      () async {
        final s = BrandServer(app)..lost = true;
        var c = await s.ready();
        expect(await c.save(item: c.pro.single, name: 'اصل تغییر'), isFalse);
        expect(c.pending.value, isNotNull);
        expect(c.canCreate, isFalse);
        c.detach();
        c = await s.ready();
        expect(c.pendingHere, isTrue);
        await c.resume();
        expect(s.mutations.length, 2);
        expect(s.mutations.first.body, s.mutations.last.body);
        expect(
          s.mutations.first.headers['idempotency-key'],
          s.mutations.last.headers['idempotency-key'],
        );
        expect(c.pending.value, isNull);
        s.permissions.removeWhere((p) => p != 'pim.brand.read');
        await c.init();
        expect(c.canCreate, isFalse);
        expect(c.canEdit(c.pro.single), isFalse);
        expect(c.canStatus(c.pro.single), isFalse);
      },
    );
    test(
      '$app add brand and edit clear preserve existing value without metadata or permission',
      () async {
        final a = BrandAddServer(app);
        final add = await a.ready();
        add.brandId.value = productId;
        expect(await add.save(name: 'محصول'), isFalse);
        expect(a.mutations, isEmpty);
        add.brandId.value = brandId;
        expect(await add.save(name: 'محصول'), isTrue);
        expect(jsonDecode(a.mutations.single.body)['brandId'], brandId);
        final s = BrandEditServer(app);
        var c = s.controller();
        await c.load();
        expect(c.values['brandId'], brandId);
        expect(await c.save({'brandId': null}), isTrue);
        expect(jsonDecode(s.patches.single.body), {
          'brandId': null,
          'expectedRevision': 9,
        });
        s.product['brandId'] = brandId;
        s.failBrands = true;
        c = s.controller();
        await c.load();
        expect(c.loadError.value, isNull);
        expect(c.brandError.value, isNotNull);
        expect(await c.save({'name': 'نام تازه'}), isTrue);
        expect(s.product['brandId'], brandId);
        s.permissions.remove('pim.brand.read');
        c = s.controller();
        await c.load();
        expect(c.canBrands, isFalse);
        expect(await c.save({'name': 'نام دوم'}), isTrue);
        expect(s.product['brandId'], brandId);
        expect(jsonDecode(s.patches.last.body).containsKey('brandId'), isFalse);
      },
    );
    testWidgets(
      '$app brand dashboard tab searches, opens form and guards switching while saving',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = BrandServer(app)..permissions.add('pim.product.read');
        s.client();
        productDashboardController.index.value = 0;
        productDashboardController.search.value = '';
        await tester.pumpWidget(
          GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: Scaffold(body: ProductDashboardScreen(appId: app)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<MyTabBar>(find.byType(MyTabBar)).tabs, [
          'محصولات',
          'ویژگی‌ها',
          'انبارها',
          'دسته‌بندی‌ها',
          'برندها',
        ]);
        expect(find.byType(ProductBrandsScreen), findsNothing);
        await tester.tap(find.text('برندها'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductBrandsScreen), findsOneWidget);
        expect(find.text('برند نمونه'), findsOneWidget);
        expect(find.text('جست‌وجوی برند'), findsNothing);
        expect(tester.widget<MyFAB>(find.byType(MyFAB)).text, 'برند جدید');
        expect(
          find.byWidgetPredicate((w) => w is BTN && w.name == 'نمایش آرشیو'),
          findsOneWidget,
        );
        final search = tester.widget<MySearchBar>(find.byType(MySearchBar));
        expect(search.enableScanner, isFalse);
        search.callback('پیدا نشود');
        await tester.pumpAndSettle();
        expect(find.text('برندی با این مشخصات موجود نیست.'), findsOneWidget);
        search.callback('نمونه');
        await tester.pumpAndSettle();
        expect(find.text('برند نمونه'), findsOneWidget);
        productBrandController.saving.value = true;
        await tester.pump();
        expect(find.byType(MyFAB), findsNothing);
        expect(
          tester
              .widget<BTN>(
                find.byWidgetPredicate(
                  (w) => w is BTN && w.name == 'نمایش آرشیو',
                ),
              )
              .disabled,
          isTrue,
        );
        tester.widget<MyTabBar>(find.byType(MyTabBar)).index(0);
        expect(productDashboardController.index.value, 4);
        productBrandController.saving.value = false;
        await tester.pumpAndSettle();
        await tester.tap(find.text('برند جدید'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('brand-name')), findsOneWidget);
        Navigator.of(tester.element(find.byType(ProductBrandForm))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(ProductBrandsScreen), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(MyTabBar),
            matching: find.text('محصولات'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProductBrandsScreen), findsNothing);
        await tester.tap(find.text('برندها'));
        await tester.pumpAndSettle();
        expect(productBrandController.query.value, '');
        expect(find.text('برند نمونه'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      '$app own brand form saves and product selector clears through edit screen',
      (tester) async {
        final s = BrandServer(app);
        s.client();
        await tester.pumpWidget(
          GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: Scaffold(body: ProductBrandsScreen(appId: app)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('برند جدید'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('brand-name')),
            matching: find.byType(TextField),
          ),
          'برند از فرم',
        );
        await tester.scrollUntilVisible(
          find.text('ذخیره برند'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('ذخیره برند'));
        await tester.pumpAndSettle();
        expect(jsonDecode(s.mutations.single.body)['name'], 'برند از فرم');
        await tester.pumpWidget(const SizedBox.shrink());
        final edit = BrandEditServer(app);
        await tester.pumpWidget(
          GetMaterialApp(
            onGenerateRoute: navigation.MikRouter(
              sharedRoutes: SharedRoutes.namedPages,
            ).generateRoute,
            theme: ThemeData(fontFamily: 'ravi'),
            home: ProductEditScreen(fx: edit.activate(), productId: productId),
          ),
        );
        await tester.pumpAndSettle();
        final picker = find.byWidgetPredicate(
          (w) => w is Dropdown && w.name == 'برند (اختیاری)',
        );
        await tester.scrollUntilVisible(
          picker,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        final field = tester.widget<Dropdown>(picker);
        expect((field.defaultValue as ItemValue).data, brandId);
        field.onChange(field.items_Value!.first);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('ذخیره تغییرات'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('ذخیره تغییرات'));
        await tester.pumpAndSettle();
        expect(edit.product['brandId'], isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
