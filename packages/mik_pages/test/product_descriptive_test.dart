import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/product/edit/screen.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_edit_fixtures.dart';

const textId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1';
const numberId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2';
const boolId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee3';
const selectId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee4';
const multiId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5';
const axisId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee6';
const otherOption = 'ffffffff-ffff-4fff-8fff-fffffffffff1';

class DescriptiveServer extends EditServer {
  DescriptiveServer(super.app) {
    permissions.addAll(['pim.attribute.read', 'pim.attribute.assign']);
  }
  bool metadataUnavailable = false;
  final attributes = <Map<String, dynamic>>[
    for (final entry in {
      textId: ['جنس', 'TEXT'],
      numberId: ['وزن', 'NUMBER'],
      boolId: ['قابل شست‌وشو', 'BOOLEAN'],
      selectId: ['کشور', 'SELECT'],
      multiId: ['کاربرد', 'MULTI_SELECT'],
      axisId: ['رنگ تنوع', 'SELECT'],
    }.entries)
      {
        ...fixturePim(
          PimResource.attributes,
          id: entry.key,
          name: entry.value[0],
        ),
        'kind': 'GENERAL',
        'dataType': entry.value[1],
        'usableForVariant': entry.key == axisId,
        'values': ['SELECT', 'MULTI_SELECT'].contains(entry.value[1])
            ? [
                {'valueId': optionId, 'name': 'گزینه یک', 'active': true},
                {'valueId': otherOption, 'name': 'گزینه دو', 'active': true},
              ]
            : [],
      },
  ];
  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/attributes')) {
      requests.add(request);
      if (metadataUnavailable) {
        return jsonResponse({
          'error': {'code': 'UNAVAILABLE', 'retryable': true},
        }, 503);
      }
      return jsonResponse(
        fixturePimPage(
          PimResource.attributes,
          items: attributes.where((a) => a['status'] == 'ACTIVE').toList(),
        ),
      );
    }
    final attribute = attributes
        .where(
          (a) => request.url.path.endsWith('/attributes/${a['attributeId']}'),
        )
        .firstOrNull;
    if (attribute != null) {
      requests.add(request);
      return jsonResponse({'businessId': 12345678, 'item': attribute});
    }
    return super.respond(request);
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
      '$app serializes five real attribute types preserving explicit zero and false; clears assignments',
      () async {
        final s = DescriptiveServer(app);
        final c = s.controller();
        await c.load();
        expect(c.loadError.value, isNull);
        expect(
          await c.save({
            'attributeValues': [
              {'attributeId': textId, 'textValue': ' پنبه '},
              {'attributeId': numberId, 'numberValue': '۰٫۰'},
              {'attributeId': boolId, 'booleanValue': false},
              {
                'attributeId': selectId,
                'valueIds': [optionId],
              },
              {
                'attributeId': multiId,
                'valueIds': [optionId, otherOption],
              },
            ],
          }),
          isTrue,
        );
        final body = jsonDecode(s.patches.single.body) as Map;
        expect(body.keys.toSet(), {'attributeValues', 'expectedRevision'});
        expect(body['expectedRevision'], 9);
        expect(body['attributeValues'], [
          {'attributeId': textId, 'textValue': 'پنبه'},
          {'attributeId': numberId, 'numberValue': 0},
          {'attributeId': boolId, 'booleanValue': false},
          {
            'attributeId': selectId,
            'valueIds': [optionId],
          },
          {
            'attributeId': multiId,
            'valueIds': [optionId, otherOption],
          },
        ]);
        expect(s.patches.single.headers['x-app-id'], app);
        await c.load();
        expect(await c.save({'attributeValues': []}), isTrue);
        expect(s.product['attributeValues'], isEmpty);
      },
    );
    test(
      '$app validation blocks empty values inactive options axis conflicts and missing permission without losing stored attributes',
      () async {
        final s = DescriptiveServer(app);
        s.product['variantAxes'] = [
          {
            'attributeId': axisId,
            'valueIds': [optionId],
          },
        ];
        final c = s.controller();
        await c.load();
        for (final value in [
          {'attributeId': boolId},
          {'attributeId': numberId, 'numberValue': ''},
          {'attributeId': numberId, 'numberValue': 'NaN'},
          {'attributeId': numberId, 'numberValue': 1000000000001},
          {
            'attributeId': axisId,
            'valueIds': [optionId],
          },
          {
            'attributeId': selectId,
            'valueIds': [optionId, otherOption],
          },
          {
            'attributeId': multiId,
            'valueIds': [optionId, optionId],
          },
          {'attributeId': textId, 'textValue': 'x' * 5001},
        ]) {
          expect(
            await c.save({
              'attributeValues': [value],
            }),
            isFalse,
          );
        }
        s.attributes.firstWhere(
          (v) => v['attributeId'] == selectId,
        )['values'] = [
          {'valueId': optionId, 'name': 'غیرفعال', 'active': false},
        ];
        await c.load();
        expect(
          await c.save({
            'attributeValues': [
              {
                'attributeId': selectId,
                'valueIds': [optionId],
              },
            ],
          }),
          isFalse,
        );
        expect(s.patches, isEmpty);
        s.product['attributeValues'] = [
          {'attributeId': boolId, 'booleanValue': false},
        ];
        s.permissions.remove('pim.attribute.assign');
        await c.load();
        expect(c.canAttributes, isFalse);
        expect(await c.save({'attributeValues': []}), isFalse);
        expect(await c.save({'name': 'نام جدید'}), isTrue);
        expect(s.product['attributeValues'], [
          {'attributeId': boolId, 'booleanValue': false},
        ]);
        s.permissions.add('pim.attribute.assign');
        s.metadataUnavailable = true;
        await c.load();
        expect(c.attributeError.value, isNotNull);
        expect(c.canAttributes, isFalse);
      },
    );
    test(
      '$app uncertain values retry original body key and revision and conflicts require reload',
      () async {
        final s = DescriptiveServer(app)..loseResponse = true;
        var c = s.controller();
        await c.load();
        final payload = [
          {'attributeId': boolId, 'booleanValue': false},
          {'attributeId': numberId, 'numberValue': '0'},
        ];
        expect(await c.save({'attributeValues': payload}), isFalse);
        c = s.controller();
        await c.load();
        expect(c.frozen.value, isTrue);
        expect(c.values['attributeValues'], [
          {'attributeId': boolId, 'booleanValue': false},
          {'attributeId': numberId, 'numberValue': 0},
        ]);
        expect(await c.save({'attributeValues': []}), isTrue);
        expect(s.patches.first.body, s.patches.last.body);
        expect(
          s.patches.first.headers['idempotency-key'],
          s.patches.last.headers['idempotency-key'],
        );
        s.loseResponse = false;
        s.conflict = true;
        await c.load();
        expect(await c.save({'attributeValues': []}), isFalse);
        expect(c.conflict.value, isTrue);
        final count = s.patches.length;
        expect(await c.save({'name': 'تغییر'}), isFalse);
        expect(s.patches, hasLength(count));
        s.conflict = false;
        await c.load();
        expect(c.conflict.value, isFalse);
      },
    );
    testWidgets(
      '$app existing product edit uses own typed inputs and saves without manufactured defaults',
      (tester) async {
        final s = DescriptiveServer(app);
        final fx = s.activate();
        await tester.pumpWidget(
          GetMaterialApp(
            theme: ThemeData(fontFamily: 'ravi'),
            home: ProductEditScreen(fx: fx, productId: productId),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byWidgetPredicate(
            (w) => w is Dropdown && w.name == 'افزودن ویژگی توصیفی',
          ),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        var picker = tester.widget<Dropdown>(
          find.byWidgetPredicate(
            (w) => w is Dropdown && w.name == 'افزودن ویژگی توصیفی',
          ),
        );
        picker.onChange(const ItemValue(text: 'وزن', data: numberId));
        await tester.pumpAndSettle();
        final numeric = find.descendant(
          of: find.byKey(const ValueKey('descriptive-$numberId')),
          matching: find.byType(TextField),
        );
        expect(tester.widget<TextField>(numeric).controller!.text, isEmpty);
        await tester.enterText(numeric, '۰');
        await tester.pumpAndSettle();
        picker = tester.widget<Dropdown>(
          find.byWidgetPredicate(
            (w) => w is Dropdown && w.name == 'افزودن ویژگی توصیفی',
          ),
        );
        picker.onChange(const ItemValue(text: 'قابل شست‌وشو', data: boolId));
        await tester.pumpAndSettle();
        final boolean = tester.widget<Dropdown>(
          find.byWidgetPredicate(
            (w) => w is Dropdown && w.name == 'قابل شست‌وشو',
          ),
        );
        expect(boolean.defaultValue, isNull);
        boolean.onChange(const ItemValue(text: 'خیر', data: false));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('ذخیره تغییرات'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('ذخیره تغییرات'));
        await tester.pumpAndSettle();
        expect(s.patches, hasLength(1));
        expect(jsonDecode(s.patches.single.body)['attributeValues'], [
          {'attributeId': numberId, 'numberValue': 0},
          {'attributeId': boolId, 'booleanValue': false},
        ]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
