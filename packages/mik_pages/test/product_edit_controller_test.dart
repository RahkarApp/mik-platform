import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/source/remote/models/models.dart';

import '../../mik_data/test/support/onboarding_fixtures.dart';
import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_edit_fixtures.dart';

void main() {
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app category edit validates primary category and preserves other fields',
      () async {
        final server = EditServer(app)
          ..permissions.add('pim.product.category.read');
        const second = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbc';
        server.categoryRows.add(fixturePim(PimResource.categories, id: second));
        final c = server.controller();
        await c.load();
        expect(
          await c.save({
            'categoryIds': [second],
            'primaryCategoryId': categoryId,
          }),
          isFalse,
        );
        expect(await c.save({'unitId': 0}), isFalse);
        expect(server.patches, isEmpty);
        expect(
          await c.save({
            'categoryIds': [second],
            'primaryCategoryId': second,
          }),
          isTrue,
        );
        expect(jsonDecode(server.patches.single.body), {
          'categoryIds': [second],
          'primaryCategoryId': second,
          'expectedRevision': 9,
        });
        expect(server.product['unitId'], 1);
      },
    );
    test(
      '$app product update sends only its changed fields and server revision',
      () async {
        final server = EditServer(app);
        final c = server.controller();
        await c.load();
        expect(c.loadError.value, isNull);
        expect(
          await c.save({...c.values, 'name': 'نام جدید', 'model': ''}),
          isTrue,
        );
        expect(jsonDecode(server.patches.single.body), {
          'name': 'نام جدید',
          'model': null,
          'expectedRevision': 9,
        });
        expect(server.product['description'], 'متن موجود');
        expect(server.patches.single.headers['x-app-id'], app);
        expect(server.patches.single.headers['idempotency-key'], isNotEmpty);
      },
    );
    test(
      '$app variant update preserves immutable identity and supports clearing SKU',
      () async {
        final server = EditServer(app);
        final c = server.controller(forVariant: true);
        await c.load();
        expect(
          await c.save({
            'sku': '',
            'barcodes': [' 123 ', '456'],
          }),
          isTrue,
        );
        expect(jsonDecode(server.patches.single.body), {
          'sku': null,
          'barcodes': ['123', '456'],
          'expectedRevision': 7,
        });
        expect(server.variant['productId'], productId);
        expect(
          server.patches.single.url.path,
          '/v1/businesses/12345678/pim/variants/$variantId',
        );
      },
    );
    test('$app unchanged form makes no empty PATCH', () async {
      final server = EditServer(app);
      final c = server.controller();
      await c.load();
      expect(await c.save(c.values), isTrue);
      expect(server.patches, isEmpty);
    });
    test(
      '$app shop permission is required only for changed descriptions',
      () async {
        final server = EditServer(app);
        final c = server.controller();
        await c.load();
        expect(await c.save({'description': 'تغییر غیرمجاز'}), isFalse);
        expect(server.patches, isEmpty);
        expect(
          await c.save({'description': 'متن موجود', 'name': 'نام جدید'}),
          isTrue,
        );
        expect(jsonDecode(server.patches.single.body).keys, [
          'name',
          'expectedRevision',
        ]);
      },
    );
    test('$app revoked update grant prevents loading edit fields', () async {
      final server = EditServer(app)..permissions.remove('pim.product.update');
      final c = server.controller();
      await c.load();
      expect(c.item, isNull);
      expect(c.loadError.value, isNotEmpty);
      expect(await c.save({'name': 'نام'}), isFalse);
      expect(server.patches, isEmpty);
    });
    test('$app archived and cross-product variants are not editable', () async {
      final server = EditServer(app);
      server.variant['productId'] = categoryId;
      final c = server.controller(forVariant: true);
      await c.load();
      expect(c.item, isNull);
      server.variant['productId'] = productId;
      server.variant['status'] = 'ARCHIVED';
      await c.load();
      expect(c.item, isNull);
      expect(server.patches, isEmpty);
    });
    test(
      '$app duplicate, empty or excessive barcodes and identity edits are rejected',
      () async {
        final server = EditServer(app);
        final c = server.controller(forVariant: true);
        await c.load();
        for (final input in [
          {
            'barcodes': ['a', ' a '],
          },
          {
            'barcodes': [''],
          },
          {'barcodes': List.generate(21, (i) => '$i')},
          {'sku': List.filled(101, 'a').join()},
          {'productId': productId},
          {'optionValues': []},
          {'status': 'ARCHIVED'},
        ]) {
          expect(await c.save(input), isFalse);
        }
        expect(server.patches, isEmpty);
      },
    );
    test(
      '$app uncertain response reopens and retries the exact original command',
      () async {
        final server = EditServer(app)..loseResponse = true;
        final c = server.controller();
        await c.load();
        expect(await c.save({'name': 'ثبت اصلی'}), isFalse);
        expect(c.frozen.value, isTrue);
        final original = server.patches.single;
        final reopened = server.controller();
        await reopened.load();
        expect(reopened.values['name'], 'ثبت اصلی');
        expect(await reopened.save({'name': 'نباید جایگزین شود'}), isTrue);
        expect(server.patches.last.body, original.body);
        expect(
          server.patches.last.headers['idempotency-key'],
          original.headers['idempotency-key'],
        );
        expect(server.product['revision'], 10);
      },
    );
    test(
      '$app revision conflict blocks resubmission until explicit reload',
      () async {
        final server = EditServer(app)..conflict = true;
        final c = server.controller();
        await c.load();
        expect(await c.save({'name': 'ویرایش'}), isFalse);
        expect(c.conflict.value, isTrue);
        expect(await c.save({'name': 'ویرایش'}), isFalse);
        expect(server.patches, hasLength(1));
        server.conflict = false;
        server.product['revision'] = 11;
        await c.load();
        expect(await c.save({'name': 'ویرایش بررسی‌شده'}), isTrue);
        expect(jsonDecode(server.patches.last.body)['expectedRevision'], 11);
        expect(
          server.patches.last.headers['idempotency-key'],
          isNot(server.patches.first.headers['idempotency-key']),
        );
      },
    );
    test(
      '$app duplicate clicks and old contexts cannot submit another patch',
      () async {
        final server = EditServer(app)
          ..pendingPatch = Completer<http.Response>();
        final c = server.controller();
        await c.load();
        final first = c.save({'name': 'ویرایش'});
        expect(await c.save({'name': 'دیگر'}), isFalse);
        while (server.patches.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        server.pendingPatch!.complete(
          jsonResponse({
            'businessId': 12345678,
            'replayed': false,
            'item': {...server.product, 'name': 'ویرایش', 'revision': 10},
          }),
        );
        expect(await first, isTrue);
        BusinessContext.clear(app);
        expect(await c.save({'name': 'بعدی'}), isFalse);
        expect(server.patches, hasLength(1));
      },
    );
  }
}
