import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';

import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_variant_fixtures.dart';
import 'support/product_axes_fixtures.dart';

void main() {
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app converts simple BASE with explicit stock classification and retained IDs',
      () async {
        final server = AxesServer(app);
        server.product['variantAxes'] = [];
        server.rows.single['combinationKey'] = 'BASE';
        server.rows.single['optionValues'] = [];
        final c = server.axesController();
        await c.load();
        expect(c.canConvert, true);
        c.select(c.attributes.first, optionId, true);
        expect(await c.save(), false);
        expect(c.error.value, contains('موجودی و سوابق'));
        expect(server.mutations, isEmpty);
        c.existingOptions[attributeId] = optionId;
        final id = server.rows.single['variantId'];
        final revision = server.rows.single['revision'];
        expect(await c.save(), true);
        final request = server.mutations.single;
        expect(request.method, 'POST');
        expect(
          request.url.path,
          endsWith('/products/$productId/convert-to-variable'),
        );
        final body = jsonDecode(request.body) as Map;
        expect(body['variantId'], id);
        expect(body['expectedVariantRevision'], revision);
        expect(body['optionValues'], [
          {'attributeId': attributeId, 'valueId': optionId},
        ]);
        expect(c.variants.single.id, id);
        expect(c.canConvert, false);
      },
    );
    test(
      '$app conversion restores the exact body and idempotency key after unknown result',
      () async {
        final server = AxesServer(app)..unavailable = true;
        server.product['variantAxes'] = [];
        server.rows.single['combinationKey'] = 'BASE';
        server.rows.single['optionValues'] = [];
        final c = server.axesController();
        await c.load();
        c.select(c.attributes.first, optionId, true);
        c.existingOptions[attributeId] = optionId;
        expect(await c.save(), false);
        expect(c.pendingAxes, true);
        final manager = server.controller();
        await manager.load();
        expect(manager.pendingAxes, true);
        server.unavailable = false;
        final restored = server.axesController();
        await restored.load();
        expect(restored.existingOptions[attributeId], optionId);
        expect(await restored.save(), true);
        final writes = server.mutations;
        expect(writes.length, 2);
        expect(writes.first.body, writes.last.body);
        expect(
          writes.first.headers['idempotency-key'],
          writes.last.headers['idempotency-key'],
        );
      },
    );

    test(
      '$app adds existing option with axes-only revision patch; no generation',
      () async {
        final s = AxesServer(app);
        final c = s.axesController();
        await c.load();
        expect(c.loadError.value, isNull);
        c.select(c.attributes.first, secondOptionId, true);
        expect(await c.save(), isTrue);
        expect(jsonDecode(s.mutations.single.body), {
          'variantAxes': [
            {
              'attributeId': attributeId,
              'valueIds': [optionId, secondOptionId],
            },
          ],
          'expectedRevision': 3,
        });
        expect(s.mutations.single.headers['x-app-id'], app);
        expect(s.rows, hasLength(1));
        expect(s.product['name'], 'پیراهن');
      },
    );
    test(
      '$app protects active options and rejects forced axis replacement',
      () async {
        final s = AxesServer(app);
        final c = s.axesController();
        await c.load();
        expect(c.canSelect(c.attributes.first, optionId), isFalse);
        c.select(c.attributes.first, optionId, false);
        expect(c.selected(attributeId, optionId), isTrue);
        expect(c.canSelect(c.attributes.last, sizeOptionId), isFalse);
        c.axes.assignAll({
          sizeAttributeId: [sizeOptionId],
        });
        expect(await c.save(), isFalse);
        expect(s.mutations, isEmpty);
      },
    );
    test(
      '$app unused options can be removed without changing active variant',
      () async {
        final s = AxesServer(app);
        s.product['variantAxes'] = [
          {
            'attributeId': attributeId,
            'valueIds': [optionId, secondOptionId],
          },
        ];
        final c = s.axesController();
        await c.load();
        c.select(c.attributes.first, secondOptionId, false);
        expect(await c.save(), isTrue);
        expect(s.rows.single['status'], 'ACTIVE');
      },
    );
    test('$app draft with no active variants can replace axis', () async {
      final s = AxesServer(app);
      s.product['status'] = 'DRAFT';
      s.rows.single['status'] = 'ARCHIVED';
      final c = s.axesController();
      await c.load();
      c.select(c.attributes.first, optionId, false);
      c.select(c.attributes.last, sizeOptionId, true);
      expect(await c.save(), isTrue);
      expect(c.product!.variantAxes.single.attributeId, sizeAttributeId);
      expect(s.rows.single['status'], 'ARCHIVED');
    });
    test(
      '$app no-op saves no request and descriptive axis is unavailable',
      () async {
        final s = AxesServer(app);
        s.product['attributeValues'] = [
          {
            'attributeId': sizeAttributeId,
            'valueIds': [sizeOptionId],
          },
        ];
        final c = s.axesController();
        await c.load();
        expect(c.canSelect(c.attributes.last, sizeOptionId), isFalse);
        expect(await c.save(), isTrue);
        expect(s.mutations, isEmpty);
      },
    );
    test(
      '$app product permissions and archived status prevent edits',
      () async {
        final s = AxesServer(app)..permissions.remove('pim.attribute.assign');
        final c = s.axesController();
        await c.load();
        expect(c.loadError.value, isNotNull);
        expect(await c.save(), isFalse);
        s.permissions.add('pim.attribute.assign');
        s.product['status'] = 'ARCHIVED';
        await c.load();
        expect(c.loadError.value, isNotNull);
        expect(s.mutations, isEmpty);
      },
    );
    test(
      '$app uncertain axes request reopens and replays exact body and key',
      () async {
        final s = AxesServer(app)..unavailable = true;
        var c = s.axesController();
        await c.load();
        c.select(c.attributes.first, secondOptionId, true);
        expect(await c.save(), isFalse);
        c = s.axesController();
        await c.load();
        expect(c.pendingAxes, isTrue);
        expect(c.locked, isTrue);
        expect(await c.save(), isTrue);
        expect(s.mutations.first.body, s.mutations.last.body);
        expect(
          s.mutations.first.headers['idempotency-key'],
          s.mutations.last.headers['idempotency-key'],
        );
      },
    );
    test(
      '$app conflict needs reload and foreign pending cannot be consumed',
      () async {
        final s = AxesServer(app)..conflict = true;
        final c = s.axesController();
        await c.load();
        c.select(c.attributes.first, secondOptionId, true);
        expect(await c.save(), isFalse);
        expect(c.conflict.value, isTrue);
        expect(await c.save(), isFalse);
        expect(s.mutations, hasLength(1));
        s.conflict = false;
        await c.load();
        expect(c.selected(attributeId, secondOptionId), isFalse);
        c.pending.value = c.fx.change(PimResource.products, {
          'name': 'نام',
        }, item: c.product);
        expect(c.pendingHere, isFalse);
        expect(await c.save(), isFalse);
        expect(s.mutations, hasLength(1));
      },
    );
    test(
      '$app validates axis and option limits and duplicate selections',
      () async {
        final s = AxesServer(app);
        final c = s.axesController();
        await c.load();
        c.axes[attributeId] = List.filled(101, optionId);
        expect(await c.save(), isFalse);
        c.axes[attributeId] = [optionId, optionId];
        expect(await c.save(), isFalse);
        c.axes.assignAll({
          for (var i = 0; i < 7; i++) '$i': [optionId],
        });
        expect(await c.save(), isFalse);
        expect(s.mutations, isEmpty);
      },
    );
    test(
      '$app new color preserves all previous option fields and awaits product save',
      () async {
        final s = AxesServer(app);
        final c = s.axesController();
        await c.load();
        final old = List.of(s.catalog.first['values'] as List);
        expect(
          await c.addOption(
            attribute: c.attributes.first,
            name: 'سبز',
            colorHex: '#00aa00',
          ),
          isTrue,
        );
        final body = jsonDecode(s.mutations.single.body) as Map;
        expect(body.keys.toSet(), {'values', 'expectedRevision'});
        expect(body['expectedRevision'], 3);
        final values = body['values'] as List;
        expect(values.take(2).toList(), old);
        expect(values.last['name'], 'سبز');
        expect(values.last['colorHex'], '#00AA00');
        expect(values.last['active'], isTrue);
        expect(
          RegExp(r'^[0-9a-f-]{36}$').hasMatch(values.last['valueId'] as String),
          isTrue,
        );
        expect(c.axes[attributeId], contains(values.last['valueId']));
        expect((s.product['variantAxes'] as List).single['valueIds'], [
          optionId,
        ]);
        expect(await c.save(), isTrue);
        expect(s.mutations, hasLength(2));
        expect(s.rows, hasLength(1));
      },
    );
    test(
      '$app color selection and name validation precede network writes',
      () async {
        final s = AxesServer(app);
        final c = s.axesController();
        await c.load();
        expect(
          await c.addOption(attribute: c.attributes.first, name: 'سبز'),
          isFalse,
        );
        expect(
          await c.addOption(
            attribute: c.attributes.first,
            name: 'سبز',
            colorHex: '#xyz',
          ),
          isFalse,
        );
        expect(
          await c.addOption(
            attribute: c.attributes.first,
            name: ' ',
            colorHex: '#00FF00',
          ),
          isFalse,
        );
        expect(s.mutations, isEmpty);
      },
    );
    test(
      '$app size option needs no color when no active axis blocks selection',
      () async {
        final s = AxesServer(app);
        s.product['status'] = 'DRAFT';
        s.rows.clear();
        final c = s.axesController();
        await c.load();
        expect(
          await c.addOption(attribute: c.attributes.last, name: 'کوچک'),
          isTrue,
        );
        expect(c.axes[sizeAttributeId], hasLength(1));
        expect(
          (jsonDecode(s.mutations.single.body)['values'] as List).last
              .containsKey('colorHex'),
          isFalse,
        );
      },
    );
    test(
      '$app attribute owner permission and option count are enforced',
      () async {
        final s = AxesServer(app);
        s.catalog.first['createdBy'] = {
          'type': 'USER',
          'identityId': sizeAttributeId,
          'membershipId': sizeAttributeId,
        };
        final c = s.axesController();
        await c.load();
        expect(c.canAddOption(c.attributes.first), isFalse);
        expect(
          await c.addOption(
            attribute: c.attributes.first,
            name: 'سبز',
            colorHex: '#00FF00',
          ),
          isFalse,
        );
        expect(s.mutations, isEmpty);
        s.permissions.add('pim.attribute.update.all');
        await c.load();
        expect(c.canAddOption(c.attributes.first), isTrue);
        s.catalog.first['values'] = List.generate(
          200,
          (i) => {
            'valueId':
                '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
            'name': 'گزینه $i',
            'colorHex': '#000000',
            'active': true,
          },
        );
        await c.load();
        expect(c.canAddOption(c.attributes.first), isFalse);
      },
    );
    test(
      '$app option retry preserves generated UUID revision and key after reopen',
      () async {
        final s = AxesServer(app)..unavailable = true;
        var c = s.axesController();
        await c.load();
        expect(
          await c.addOption(
            attribute: c.attributes.first,
            name: 'سبز',
            colorHex: '#00FF00',
          ),
          isFalse,
        );
        c = s.axesController();
        await c.load();
        expect(c.pendingOption, isTrue);
        expect(await c.addOption(), isTrue);
        expect(s.mutations.first.body, s.mutations.last.body);
        expect(
          s.mutations.first.headers['idempotency-key'],
          s.mutations.last.headers['idempotency-key'],
        );
        expect((s.catalog.first['values'] as List), hasLength(3));
      },
    );
    test(
      '$app option conflict cannot overwrite a concurrent attribute change',
      () async {
        final s = AxesServer(app)..conflict = true;
        final c = s.axesController();
        await c.load();
        expect(
          await c.addOption(
            attribute: c.attributes.first,
            name: 'سبز',
            colorHex: '#00FF00',
          ),
          isFalse,
        );
        expect(c.conflict.value, isTrue);
        expect(
          await c.addOption(
            attribute: c.attributes.first,
            name: 'سبز',
            colorHex: '#00FF00',
          ),
          isFalse,
        );
        expect(s.mutations, hasLength(1));
        s.conflict = false;
        await c.load();
        expect(c.conflict.value, isFalse);
        expect(c.axes[attributeId], [optionId]);
      },
    );
    test('$app changed business cannot write axes or global options', () async {
      final s = AxesServer(app);
      final c = s.axesController();
      await c.load();
      BusinessContext.clear(app);
      expect(await c.save(), isFalse);
      expect(
        await c.addOption(
          attribute: c.attributes.first,
          name: 'سبز',
          colorHex: '#00FF00',
        ),
        isFalse,
      );
      expect(s.mutations, isEmpty);
    });
  }
}
