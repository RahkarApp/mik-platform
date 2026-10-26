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
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/screen/screen.dart';
import 'package:mik_pages/product/screen/tabs/controllers/cat.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const childId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';

class CategoryServer {
  final String app;
  CategoryServer(this.app);
  final permissions = [
    'pim.product.category.read',
    'pim.product.category.create',
    'pim.product.category.update',
    'pim.product.category.delete',
    'pim.product.category.import',
  ];
  final rows = <Map<String, dynamic>>[
    {...fixturePim(PimResource.categories), 'templateCode': '01'},
  ];
  final requests = <http.Request>[], replies = <String, http.Response>{};
  bool unavailable = false, conflict = false;
  List<http.Request> get mutations =>
      requests.where((r) => r.method != 'GET').toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      return jsonResponse(fixtureAuthorization(permissions));
    }
    if (path.endsWith('/catalog/products')) {
      final parent = request.url.queryParameters['parentCode'];
      return jsonResponse({
        'version': 1,
        'items': parent == null
            ? [
                {'id': '01', 'name': 'پوشاک', 'parent': null},
              ]
            : parent == '01'
            ? [
                {'id': '0101', 'name': 'پوشاک کودک', 'parent': '01'},
              ]
            : [],
        'units': [],
        'nextCursor': null,
      });
    }
    if (request.method == 'GET') {
      return jsonResponse(fixturePimPage(PimResource.categories, items: rows));
    }
    final key = request.headers['idempotency-key']!;
    if (replies.containsKey(key)) return replies[key]!;
    if (conflict) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    final body = Map<String, dynamic>.from(jsonDecode(request.body));
    http.Response response;
    if (path.endsWith('/categories/import')) {
      if (!rows.any((v) => v['categoryId'] == childId)) {
        rows.add({
          ...fixturePim(
            PimResource.categories,
            id: childId,
            name: 'پوشاک کودک',
          ),
          'parentId': categoryId,
          'templateCode': '0101',
        });
      }
      response = jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'importedCount': 1,
        'catalogVersion': 1,
      });
    } else if (request.method == 'POST') {
      final row = {
        ...fixturePim(PimResource.categories, id: childId),
        'source': 'CUSTOM',
        ...body,
      };
      rows.add(row);
      response = jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'item': row,
      });
    } else {
      final row = rows.firstWhere(
        (v) => v['categoryId'] == request.url.pathSegments.last,
      );
      if (body['expectedRevision'] != row['revision']) {
        return jsonResponse({
          'error': {'code': 'REVISION_CONFLICT'},
        }, 409);
      }
      if (body['status'] == 'ARCHIVED' &&
          rows.any(
            (v) =>
                v['parentId'] == row['categoryId'] && v['status'] == 'ACTIVE',
          )) {
        return jsonResponse({
          'error': {'code': 'RECORD_IN_USE'},
        }, 409);
      }
      body.remove('expectedRevision');
      row.addAll(body);
      row['revision'] = (row['revision'] as int) + 1;
      response = jsonResponse({
        'businessId': 12345678,
        'replayed': false,
        'item': row,
      });
    }
    replies[key] = response;
    return unavailable
        ? jsonResponse({
            'error': {'code': 'UNAVAILABLE', 'retryable': true},
          }, 503)
        : response;
  }

  void activate() => pimFixture(MockClient(respond), appId: app);
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
      '$app category create edit tree search and guarded archive use UUIDs',
      () async {
        final s = CategoryServer(app)..activate();
        final c = CatTabDashboardController();
        await c.attach(app);
        expect(
          await c.saveCategory(
            name: 'کفش',
            description: 'توضیح',
            parentId: null,
          ),
          isFalse,
        );
        expect(s.mutations, isEmpty);
        expect(
          await c.saveCategory(
            name: 'کفش',
            description: 'توضیح',
            parentId: categoryId,
          ),
          isTrue,
        );
        var child = c.cat.singleWhere((v) => v.id == childId);
        expect(c.parents(child).map((v) => v.id), [categoryId]);
        expect(
          await c.saveCategory(
            item: child,
            name: 'کفش بچه',
            description: '',
            parentId: categoryId,
          ),
          isTrue,
        );
        expect(jsonDecode(s.mutations.last.body), {
          'name': 'کفش بچه',
          'description': null,
          'expectedRevision': 3,
        });
        c.search('بچه');
        expect(c.visibleIds, {categoryId, childId});
        await c.changeStatus(c.cat.first);
        expect(c.commandError.value, contains('زیر‌دسته'));
        expect(c.cat.first.status, 'ACTIVE');
        child = c.cat.singleWhere((v) => v.id == childId);
        await c.changeStatus(child);
        expect(c.cat.last.status, 'ARCHIVED');
        await c.changeStatus(c.cat.last);
        expect(c.cat.last.status, 'ACTIVE');
        expect(s.mutations.every((r) => r.headers['x-app-id'] == app), isTrue);
        c.detach();
      },
    );
    test(
      '$app catalog import preserves codes and permissions are independent',
      () async {
        final s = CategoryServer(app)..activate();
        final c = CatTabDashboardController();
        await c.attach(app);
        await c.loadCatalog();
        await c.loadCatalog(parent: '01');
        expect(c.catalog['']!.single.id, '01');
        expect(c.catalog['01']!.single.id, '0101');
        await c.importCategory(c.catalog['']!.single);
        expect(jsonDecode(s.mutations.single.body), {
          'codes': ['01'],
        });
        expect(c.cat, hasLength(2));
        s.permissions.remove('pim.product.category.create');
        await c.init();
        expect(c.canCreate, isFalse);
        expect(c.canImport, isTrue);
        s.permissions.remove('pim.product.category.read');
        await c.init();
        expect(c.error.value, isNotNull);
        expect(c.cat, isEmpty);
        c.detach();
      },
    );
    test(
      '$app uncertain command resumes unchanged and conflict needs reload',
      () async {
        final s = CategoryServer(app)..unavailable = true;
        s.activate();
        var c = CatTabDashboardController();
        await c.attach(app);
        expect(
          await c.saveCategory(
            name: 'کفش',
            description: '',
            parentId: categoryId,
          ),
          isFalse,
        );
        expect(c.pendingHere, isTrue);
        c.detach();
        c = CatTabDashboardController();
        await c.attach(app);
        await c.resume();
        expect(c.pending.value, isNull);
        expect(s.mutations.first.body, s.mutations.last.body);
        expect(
          s.mutations.first.headers['idempotency-key'],
          s.mutations.last.headers['idempotency-key'],
        );
        s.unavailable = false;
        s.conflict = true;
        await c.changeStatus(c.cat.last);
        expect(c.conflict.value, isTrue);
        final count = s.mutations.length;
        await c.changeStatus(c.cat.last);
        expect(s.mutations, hasLength(count));
        s.conflict = false;
        await c.init();
        expect(c.conflict.value, isFalse);
        BusinessContext.clear(app);
        expect(c.canCreate, isFalse);
        c.detach();
      },
    );
    testWidgets(
      '$app existing dashboard category tab creates through native form',
      (tester) async {
        final s = CategoryServer(app)..activate();
        productDashboardController.index.value = 3;
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
        expect(find.byType(CatTabDashboard), findsOneWidget);
        expect(find.text('پوشاک'), findsOneWidget);
        await tester.tap(find.text('دسته‌بندی جدید'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('افزودن سفارشی'));
        await tester.pumpAndSettle();
        expect(find.byType(Input), findsWidgets);
        expect(find.byType(Dropdown), findsOneWidget);
        final form = find.byType(AddCategoryForm);
        final fields = find.descendant(
          of: form,
          matching: find.byType(TextField),
        );
        await tester.enterText(fields.first, 'کفش');
        tester
            .widget<Dropdown>(find.byType(Dropdown))
            .onChange(const ItemValue(text: 'پوشاک', data: categoryId));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('افزودن و بازگشت'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('افزودن و بازگشت'));
        await tester.pumpAndSettle();
        expect(find.byType(CatManageScreen), findsNothing);
        expect(s.mutations, hasLength(1));
        await tester.tap(find.text('پوشاک'));
        await tester.pumpAndSettle();
        expect(find.text('کفش'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
