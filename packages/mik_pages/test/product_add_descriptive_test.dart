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
import 'package:mik_pages/product/add/screen.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_add_fixtures.dart';

const textId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1';
const numberId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2';
const boolId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee3';
const selectId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee4';
const multiId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5';
const otherOption = 'ffffffff-ffff-4fff-8fff-fffffffffff1';

class AddDescriptiveServer extends AddServer {
  AddDescriptiveServer(super.app);
  bool lostCreate = false;
  final replies = <String, http.Response>{};
  final attributes = <Map<String, dynamic>>[
    for (final e in {
      textId: ['جنس', 'TEXT'],
      numberId: ['وزن', 'NUMBER'],
      boolId: ['قابل شست‌وشو', 'BOOLEAN'],
      selectId: ['کشور', 'SELECT'],
      multiId: ['کاربرد', 'MULTI_SELECT'],
    }.entries)
      {
        ...fixturePim(PimResource.attributes, id: e.key, name: e.value[0]),
        'kind': 'GENERAL',
        'dataType': e.value[1],
        'usableForVariant': e.key == selectId,
        'values': ['SELECT', 'MULTI_SELECT'].contains(e.value[1])
            ? [
                {'valueId': optionId, 'name': 'گزینه یک', 'active': true},
                {'valueId': otherOption, 'name': 'گزینه دو', 'active': true},
              ]
            : [],
      },
  ];
  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.method == 'GET' && request.url.path.endsWith('/attributes')) {
      requests.add(request);
      return jsonResponse(
        fixturePimPage(PimResource.attributes, items: attributes),
      );
    }
    if (request.method == 'POST' && request.url.path.endsWith('/products')) {
      requests.add(request);
      final key = request.headers['idempotency-key']!;
      if (replies.containsKey(key)) return replies[key]!;
      final result = created(request);
      replies[key] = result;
      return lostCreate
          ? jsonResponse({
              'error': {'code': 'UNAVAILABLE', 'retryable': true},
            }, 503)
          : result;
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
      '$app create validates descriptive values and axis conflict then sends five typed values without variant grants',
      () async {
        final s = AddDescriptiveServer(app);
        final c = await s.ready();
        c.attributeDraft.add({'attributeId': boolId});
        expect(await c.save(name: 'محصول'), isFalse);
        expect(s.mutations, isEmpty);
        c.attributeDraft.assignAll([
          {
            'attributeId': selectId,
            'valueIds': [optionId],
          },
        ]);
        c.option(selectId, optionId, true);
        expect(c.axes, isEmpty);
        c.axes[selectId] = [optionId];
        expect(await c.save(name: 'محصول'), isFalse);
        expect(s.mutations, isEmpty);
        c.axes.clear();
        c.attributeDraft.assignAll([
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
        ]);
        s.permissions.remove('pim.variant.create');
        s.permissions.remove('pim.variant.read');
        await c.load();
        expect(c.canAttributes, isTrue);
        expect(c.canAxes, isFalse);
        expect(await c.save(name: 'محصول'), isTrue);
        expect(s.mutations, hasLength(1));
        final body = jsonDecode(s.mutations.single.body);
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
        expect(body['status'], 'DRAFT');
        expect(body.containsKey('variantAxes'), isFalse);
        expect(s.mutations.single.headers['x-app-id'], app);
      },
    );
    test(
      '$app original create body survives lost reply and reopening; missing assign sends no data',
      () async {
        final s = AddDescriptiveServer(app)..lostCreate = true;
        var c = await s.ready();
        c.attributeDraft.add({'attributeId': numberId, 'numberValue': '0'});
        expect(await c.save(name: 'اصل محصول'), isFalse);
        expect(c.locked.value, isTrue);
        c = s.controller();
        await c.load();
        expect(c.recovery.drafts.single.fields['attributeValues'], [
          {'attributeId': numberId, 'numberValue': 0},
        ]);
        expect(await c.save(name: 'نباید ثبت شود'), isTrue);
        expect(s.mutations, hasLength(2));
        expect(s.replies, hasLength(1));
        expect(s.mutations.first.body, s.mutations.last.body);
        expect(
          s.mutations.first.headers['idempotency-key'],
          s.mutations.last.headers['idempotency-key'],
        );
        final restricted = AddDescriptiveServer(app)
          ..permissions.remove('pim.attribute.assign');
        final d = await restricted.ready();
        expect(d.canAttributes, isFalse);
        d.attributeDraft.add({'attributeId': boolId, 'booleanValue': false});
        expect(await d.save(name: 'محصول'), isFalse);
        expect(restricted.mutations, isEmpty);
      },
    );
    testWidgets(
      '$app add form uses shared typed inputs and creates explicit zero and false',
      (tester) async {
        final s = AddDescriptiveServer(app);
        final c = s.controller();
        await tester.pumpWidget(
          GetMaterialApp(
            theme: ThemeData(fontFamily: 'ravi'),
            home: PimProductAddScreen(context: c.fx.context, controller: c),
          ),
        );
        await tester.pumpAndSettle();
        c.category(categoryId, true);
        c.unitId.value = 1;
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('product-name')),
            matching: find.byType(TextField),
          ),
          'محصول با مشخصات',
        );
        final picker = find.byWidgetPredicate(
          (w) => w is Dropdown && w.name == 'افزودن ویژگی توصیفی',
        );
        await tester.scrollUntilVisible(
          picker,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        tester
            .widget<Dropdown>(picker)
            .onChange(const ItemValue(text: 'وزن', data: numberId));
        await tester.pumpAndSettle();
        final number = find.descendant(
          of: find.byKey(const ValueKey('descriptive-$numberId')),
          matching: find.byType(TextField),
        );
        expect(tester.widget<TextField>(number).controller!.text, isEmpty);
        await tester.enterText(number, '۰');
        await tester.pumpAndSettle();
        tester
            .widget<Dropdown>(picker)
            .onChange(const ItemValue(text: 'قابل شست‌وشو', data: boolId));
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
          find.text('ثبت محصول'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('ثبت محصول'));
        await tester.pumpAndSettle();
        expect(s.mutations, hasLength(1));
        expect(jsonDecode(s.mutations.single.body)['attributeValues'], [
          {'attributeId': numberId, 'numberValue': 0},
          {'attributeId': boolId, 'booleanValue': false},
        ]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
