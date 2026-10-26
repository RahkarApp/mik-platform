import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/screen/screen.dart';
import 'package:mik_pages/product/screen/tabs/controllers/product.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const brandId = '11111111-1111-4111-8111-111111111119';
const nextId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaab';
const otherCategory = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbc';

class FilterServer {
  final String app;
  FilterServer(this.app);
  final permissions = [
    'pim.product.read',
    'pim.brand.read',
    'pim.product.category.read',
  ];
  final requests = <http.Request>[];
  bool more = false, failNext = false, failMetadata = false;
  Future<http.Response> Function(http.Request)? custom;
  List<http.Request> get products =>
      requests.where((r) => r.url.path.endsWith('/products')).toList();
  void bind() {
    pimFixture(MockClient(respond), appId: app);
  }

  Future<http.Response> respond(http.Request r) async {
    requests.add(r);
    final path = r.url.path;
    if (path.endsWith('/authorization')) {
      return jsonResponse(fixtureAuthorization(permissions));
    }
    if (path.endsWith('/brands') || path.endsWith('/categories')) {
      if (failMetadata) {
        return jsonResponse({
          'error': {'code': 'UNAVAILABLE', 'retryable': true},
        }, 503);
      }
      final resource = path.endsWith('/brands')
          ? PimResource.brands
          : PimResource.categories;
      return jsonResponse(fixturePimPage(resource));
    }
    if (!path.endsWith('/products')) throw StateError('Unexpected route $path');
    if (custom != null) return custom!(r);
    if (failNext && r.url.queryParameters['after'] != null) {
      throw http.ClientException('offline');
    }
    return page(
      r,
      next: more && !r.url.queryParameters.containsKey('after')
          ? productId
          : null,
    );
  }

  http.Response page(
    http.Request r, {
    String? next,
    String? name,
    String? category,
    String? brand,
  }) {
    final q = r.url.queryParameters;
    return jsonResponse(
      fixturePimPage(
        PimResource.products,
        items: [
          {
            ...fixturePim(
              PimResource.products,
              id: q['after'] == null ? productId : nextId,
              name: name ?? 'پیراهن',
              status: q['status'] ?? 'DRAFT',
            ),
            'brandId': brand ?? q['brandId'] ?? brandId,
            'categoryIds': [category ?? q['categoryId'] ?? categoryId],
          },
        ],
        next: next,
      ),
    );
  }
}

Future<void> finish(ProductTabDashboardController c) async {
  for (var n = 0; n < 150 && c.loading.value; n++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(c.loading.value, isFalse);
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
      '$app combines real brand category and draft filters, retries cursor and resets',
      () async {
        final s = FilterServer(app)
          ..more = true
          ..bind();
        final c = ProductTabDashboardController();
        addTearDown(c.onClose);
        await c.attach(app);
        await c.loadMore();
        c.brandId.value = brandId;
        c.filteredCatId.add(categoryId);
        c.typeFilter.value = 'پیش‌نویس';
        await c.init();
        expect(s.products.last.url.queryParameters, {
          'limit': '100',
          'status': 'DRAFT',
          'brandId': brandId,
          'categoryId': categoryId,
        });
        expect(c.filtered.value, isTrue);
        expect(c.prd.single.status, 'DRAFT');
        s.failNext = true;
        await c.loadMore();
        expect(c.moreError.value, isNotNull);
        expect(c.prd, hasLength(1));
        s.failNext = false;
        await c.loadMore();
        expect(c.prd, hasLength(2));
        expect(s.products.last.url.queryParameters['after'], productId);
        expect(s.products.last.url.queryParameters['brandId'], brandId);
        c.typeFilter.value = 'همه';
        await c.init();
        expect(
          s.products.last.url.queryParameters.containsKey('status'),
          isFalse,
        );
        await c.attach(app);
        expect(c.brandId.value, brandId);
        expect(c.filteredCatId, [categoryId]);
        await c.resetFilters();
        expect(s.products.last.url.queryParameters, {
          'limit': '100',
          'status': 'ACTIVE',
        });
        expect(c.brandId.value, isNull);
        expect(c.filtered.value, isFalse);
        expect(
          s.products.every(
            (r) => r.method == 'GET' && r.headers['x-app-id'] == app,
          ),
          isTrue,
        );
      },
    );
    test(
      '$app search and multiple categories cover all brand pages; stale results cannot replace filters',
      () async {
        final s = FilterServer(app)..bind();
        final c = ProductTabDashboardController();
        addTearDown(c.onClose);
        await c.attach(app);
        s.custom = (r) async => s.page(
          r,
          next: r.url.queryParameters['after'] == null ? productId : null,
          name: r.url.queryParameters['after'] == null
              ? 'بدون تطابق'
              : 'کیف ۱۲',
          category: r.url.queryParameters['after'] == null
              ? categoryId
              : otherCategory,
        );
        c.brandId.value = brandId;
        c.filteredCatId.assignAll([
          otherCategory,
          'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbd',
        ]);
        c.search('کیف12');
        await finish(c);
        expect(c.prd.single.id, nextId);
        expect(c.hasMore.value, isFalse);
        for (final r in s.products.skip(1)) {
          expect(r.url.queryParameters['brandId'], brandId);
          expect(r.url.queryParameters.keys, isNot(contains('categoryId')));
          expect(r.url.queryParameters.keys, isNot(contains('search')));
        }
        final started = Completer<void>(), old = Completer<http.Response>();
        s.custom = (r) async {
          started.complete();
          return old.future;
        };
        final stale = c.init();
        await started.future;
        s.custom = (r) async =>
            s.page(r, name: 'کیف ۱۲', category: otherCategory);
        c.typeFilter.value = 'آرشیو';
        await c.init();
        old.complete(
          s.page(
            s.products[s.products.length - 2],
            name: 'کیف ۱۲',
            category: otherCategory,
          ),
        );
        await stale;
        expect(c.prd.single.status, 'ARCHIVED');
        expect(c.error.value, isNull);
      },
    );
    test(
      '$app metadata error or removed grants preserves filters; invalid filtered response is rejected',
      () async {
        final s = FilterServer(app)..bind();
        final c = ProductTabDashboardController();
        addTearDown(c.onClose);
        await c.attach(app);
        c.brandId.value = brandId;
        c.filteredCatId.add(categoryId);
        s.failMetadata = true;
        await c.init();
        expect(c.error.value, isNull);
        expect(c.prd, hasLength(1));
        expect(c.brandError.value, isNotNull);
        expect(c.categoryError.value, isNotNull);
        expect(c.brandId.value, brandId);
        expect(c.filteredCatId, [categoryId]);
        s.permissions.removeWhere((v) => v != 'pim.product.read');
        await c.init();
        expect(c.canFilterBrands, isFalse);
        expect(c.canFilterCategories, isFalse);
        expect(c.prd, hasLength(1));
        expect(s.products.last.url.queryParameters['brandId'], brandId);
        s.custom = (r) async => s.page(r, brand: productId);
        await c.init();
        expect(c.error.value, isNotNull);
        expect(c.prd, isEmpty);
        s.custom = null;
        s.bind();
        await c.attach(app);
        expect(c.brandId.value, isNull);
        expect(c.filteredCatId, isEmpty);
        expect(c.typeFilter.value, 'فعال');
      },
    );
    testWidgets(
      '$app existing filter sheet selects brand and draft, clears selections and keeps unsupported controls disabled',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = FilterServer(app)..bind();
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
        c.filter(tester.element(find.byType(ProductTabDashboard)));
        await tester.pumpAndSettle();
        expect(tester.widget<MyTab>(find.byType(MyTab).last).enabledValues, {
          'همه',
          'فعال',
          'پیش‌نویس',
          'آرشیو',
        });
        expect(
          tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged,
          isNull,
        );
        final picker = find.byWidgetPredicate(
          (w) => w is Dropdown && w.name == 'برند',
        );
        final dropdown = tester.widget<Dropdown>(picker);
        dropdown.onChange(
          dropdown.items_Value!.firstWhere((v) => v.data == brandId),
        );
        await tester.pumpAndSettle();
        expect(c.brandId.value, brandId);
        expect(s.products.last.url.queryParameters['brandId'], brandId);
        await tester.tap(find.text('پیش‌نویس'));
        await tester.pumpAndSettle();
        expect(s.products.last.url.queryParameters['status'], 'DRAFT');
        await tester.tap(find.text('موجود'));
        await tester.pumpAndSettle();
        expect(c.typeFilter.value, 'پیش‌نویس');
        await tester.ensureVisible(find.text('حذف همه فیلتر‌ها'));
        await tester.tap(find.text('حذف همه فیلتر‌ها'));
        await tester.pumpAndSettle();
        expect(c.filtered.value, isFalse);
        expect(c.brandId.value, isNull);
        expect(c.typeFilter.value, 'فعال');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
