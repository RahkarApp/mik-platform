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
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/property/form.dart';
import 'package:mik_pages/product/screen/screen.dart';
import 'package:mik_pages/product/screen/tabs/controllers/property.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';

const newAttributeId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1';
const newOptionId = 'ffffffff-ffff-4fff-8fff-fffffffffff1';

class AttributeServer {
  final String app;
  AttributeServer(this.app);
  final permissions = [
    'pim.attribute.read',
    'pim.attribute.create',
    'pim.attribute.update',
    'pim.attribute.delete',
  ];
  final rows = <Map<String, dynamic>>[
    {
      ...fixturePim(PimResource.attributes),
      'values': [
        {
          'valueId': optionId,
          'name': 'قرمز',
          'code': 'RED',
          'colorHex': '#FF0000',
          'active': true,
        },
      ],
    },
  ];
  final requests = <http.Request>[], replies = <String, http.Response>{};
  bool used = false, unavailable = false, conflict = false;
  List<http.Request> get mutations =>
      requests.where((r) => r.method != 'GET').toList();
  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/authorization')) {
      return jsonResponse(fixtureAuthorization(permissions));
    }
    if (path.endsWith('/catalog/products')) {
      return jsonResponse({
        'version': 1,
        'items': [],
        'units': [],
        'nextCursor': null,
      });
    }
    if (request.method == 'GET') {
      return jsonResponse(fixturePimPage(PimResource.attributes, items: rows));
    }
    final key = request.headers['idempotency-key']!;
    if (replies.containsKey(key)) return replies[key]!;
    if (conflict) {
      return jsonResponse({
        'error': {'code': 'REVISION_CONFLICT'},
      }, 409);
    }
    final body = Map<String, dynamic>.from(jsonDecode(request.body));
    Map<String, dynamic> row;
    if (request.method == 'POST') {
      row = {
        ...fixturePim(PimResource.attributes, id: newAttributeId),
        ...body,
      };
      rows.add(row);
    } else {
      row = rows.firstWhere(
        (v) => v['attributeId'] == request.url.pathSegments.last,
      );
      if (body['expectedRevision'] != row['revision']) {
        return jsonResponse({
          'error': {'code': 'REVISION_CONFLICT'},
        }, 409);
      }
      if (used &&
          (body['status'] == 'ARCHIVED' ||
              [
                'kind',
                'dataType',
                'usableForVariant',
              ].any((k) => body.containsKey(k) && body[k] != row[k]) ||
              body['values'] is List &&
                  (row['values'] as List).any(
                    (old) => !(body['values'] as List).any(
                      (v) =>
                          v['valueId'] == old['valueId'] && v['active'] == true,
                    ),
                  ))) {
        return jsonResponse({
          'error': {'code': 'RECORD_IN_USE'},
        }, 409);
      }
      body.remove('expectedRevision');
      row.addAll(body);
      row['revision'] = (row['revision'] as int) + 1;
    }
    final response = jsonResponse({
      'businessId': 12345678,
      'replayed': false,
      'item': row,
    });
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
      '$app edits options with stable IDs and preserves optional fields; validates color and type',
      () async {
        final s = AttributeServer(app)..activate();
        final c = ProductPropertyTabDashboardController();
        await c.attach(app);
        final item = c.pro.single;
        expect(
          await c.save(
            item: item,
            name: item.name,
            kind: 'COLOR',
            dataType: 'TEXT',
            usableForVariant: true,
            values: [],
          ),
          isFalse,
        );
        expect(
          await c.save(
            item: item,
            name: item.name,
            kind: 'COLOR',
            dataType: 'SELECT',
            usableForVariant: true,
            values: [const PimOption(valueId: newOptionId, name: 'سیاه')],
          ),
          isFalse,
        );
        expect(s.mutations, isEmpty);
        final options = [
          ...item.values,
          const PimOption(
            valueId: newOptionId,
            name: 'سیاه',
            colorHex: '#000000',
          ),
        ];
        expect(
          await c.save(
            item: item,
            name: item.name,
            kind: item.kind,
            dataType: item.dataType,
            usableForVariant: item.usableForVariant,
            values: options,
          ),
          isTrue,
        );
        final body = jsonDecode(s.mutations.single.body) as Map;
        expect(body.keys.toSet(), {'values', 'expectedRevision'});
        expect((body['values'] as List).first, {
          'valueId': optionId,
          'name': 'قرمز',
          'code': 'RED',
          'colorHex': '#FF0000',
          'active': true,
        });
        expect(body['expectedRevision'], 3);
        expect(s.mutations.single.headers['x-app-id'], app);
        c.detach();
      },
    );
    test(
      '$app owner permissions and used attribute archive are enforced',
      () async {
        final s = AttributeServer(app)..used = true;
        s.activate();
        final c = ProductPropertyTabDashboardController();
        await c.attach(app);
        await c.changeStatus(c.pro.single);
        expect(c.commandError.value, contains('استفاده'));
        expect(c.pro.single.status, 'ACTIVE');
        s.used = false;
        await c.changeStatus(c.pro.single);
        expect(c.pro.single.status, 'ARCHIVED');
        await c.changeStatus(c.pro.single);
        expect(c.pro.single.status, 'ACTIVE');
        s.rows.single['createdBy'] = {
          'type': 'USER',
          'identityId': newAttributeId,
        };
        await c.init();
        expect(c.canEdit(c.pro.single), isFalse);
        expect(c.canStatus(c.pro.single), isFalse);
        s.permissions.addAll([
          'pim.attribute.update.all',
          'pim.attribute.delete.all',
        ]);
        await c.init();
        expect(c.canEdit(c.pro.single), isTrue);
        expect(c.canStatus(c.pro.single), isTrue);
        c.detach();
      },
    );
    test(
      '$app uncertain create replays original UUID options key and revision conflict requires reload',
      () async {
        final s = AttributeServer(app)..unavailable = true;
        s.activate();
        var c = ProductPropertyTabDashboardController();
        await c.attach(app);
        expect(
          await c.save(
            name: 'سایز',
            kind: 'SIZE',
            dataType: 'SELECT',
            usableForVariant: true,
            values: [const PimOption(valueId: newOptionId, name: 'بزرگ')],
          ),
          isFalse,
        );
        expect(c.pendingHere, isTrue);
        c.detach();
        c = ProductPropertyTabDashboardController();
        await c.attach(app);
        await c.resume();
        expect(c.pending.value, isNull);
        expect(s.mutations.first.body, s.mutations.last.body);
        expect(
          s.mutations.first.headers['idempotency-key'],
          s.mutations.last.headers['idempotency-key'],
        );
        expect(s.rows, hasLength(2));
        s.unavailable = false;
        s.conflict = true;
        await c.changeStatus(c.pro.first);
        expect(c.conflict.value, isTrue);
        final count = s.mutations.length;
        await c.changeStatus(c.pro.first);
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
      '$app defines a color in the existing feature tab with native form and picker',
      (tester) async {
        final s = AttributeServer(app)..activate();
        productDashboardController.index.value = 1;
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
        expect(find.byType(ProductPropertyTabDashboard), findsOneWidget);
        await tester.tap(find.text('ویژگی جدید'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductAttributeForm), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('attribute-name')),
            matching: find.byType(TextField),
          ),
          'رنگ بسته‌بندی',
        );
        tester.widget<Dropdown>(find.byType(Dropdown).first).onChange('رنگ');
        await tester.pumpAndSettle();
        tester
            .widget<MyTab>(find.byType(MyTab))
            .callback('قابل استفاده در تنوع');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('افزودن گزینه'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('افزودن گزینه'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('attribute-option-name')),
            matching: find.byType(TextField),
          ),
          'مشکی',
        );
        await tester.tap(find.text('انتخاب رنگ'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('تأیید رنگ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('تأیید رنگ'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ثبت گزینه در فرم'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ثبت گزینه در فرم'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ذخیره ویژگی'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ذخیره ویژگی'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductAttributeForm), findsNothing);
        expect(find.text('رنگ بسته‌بندی'), findsOneWidget);
        expect(s.mutations, hasLength(1));
        final body = jsonDecode(s.mutations.single.body);
        expect(body['kind'], 'COLOR');
        expect(body['usableForVariant'], isTrue);
        expect((body['values'] as List).single['colorHex'], '#000000');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
