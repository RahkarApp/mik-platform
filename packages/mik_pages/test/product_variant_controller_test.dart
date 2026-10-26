import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';

import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_variant_fixtures.dart';

void main() {
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app preview and generate use exact selected axes and app scope',
      () async {
        final s = VariantServer(app);
        final c = s.controller();
        await c.load();
        expect(c.loadError.value, isNull);
        c.select(attributeId, optionId, false);
        await c.showPreview();
        expect(c.preview.value!.combinations, hasLength(1));
        expect(c.existing(c.preview.value!.combinations.single), isNull);
        await c.generate();
        expect(c.variants, hasLength(2));
        final req = s.mutations.single;
        expect(req.headers['x-app-id'], app);
        expect(jsonDecode(req.body), {
          'productId': productId,
          'axes': [
            {
              'attributeId': attributeId,
              'valueIds': [secondOptionId],
            },
          ],
        });
        expect(c.notice.value, contains('1 تنوع جدید'));
      },
    );
    test('$app generating does not restore archived combinations', () async {
      final s = VariantServer(app);
      s.rows.single['status'] = 'ARCHIVED';
      final c = s.controller();
      await c.load();
      await c.showPreview();
      expect(
        c.existing(c.preview.value!.combinations.first)!.status,
        'ARCHIVED',
      );
      await c.generate();
      expect(c.variants.first.status, 'ARCHIVED');
    });
    test(
      '$app last active variant is protected; explicit restore needs update',
      () async {
        final s = VariantServer(app);
        final c = s.controller();
        await c.load();
        expect(c.canChange(c.variants.single), isFalse);
        await c.changeStatus(c.variants.single);
        expect(s.mutations, isEmpty);
        s.rows.single['status'] = 'ARCHIVED';
        await c.load();
        expect(c.canChange(c.variants.single), isTrue);
        await c.changeStatus(c.variants.single);
        expect(jsonDecode(s.mutations.single.body), {
          'status': 'ACTIVE',
          'expectedRevision': 3,
        });
        expect(c.variants.single.status, 'ACTIVE');
      },
    );
    test('$app delete permission is independent from update', () async {
      final s = VariantServer(app)..permissions.remove('pim.variant.update');
      s.product['status'] = 'DRAFT';
      final c = s.controller();
      await c.load();
      expect(c.canChange(c.variants.single), isTrue);
      await c.changeStatus(c.variants.single);
      expect(c.variants.single.status, 'ARCHIVED');
      expect(c.canChange(c.variants.single), isFalse);
    });
    test(
      '$app empty selection invalidates preview and sends nothing',
      () async {
        final s = VariantServer(app);
        final c = s.controller();
        await c.load();
        await c.showPreview();
        c.select(attributeId, optionId, false);
        expect(c.preview.value, isNull);
        c.select(attributeId, secondOptionId, false);
        await c.showPreview();
        await c.generate();
        expect(c.error.value, isNotNull);
        expect(s.mutations, isEmpty);
      },
    );
    test('$app malformed server preview is refused', () async {
      final s = VariantServer(app)..invalidPreview = true;
      final c = s.controller();
      await c.load();
      await c.showPreview();
      await c.generate();
      expect(c.preview.value, isNull);
      expect(c.error.value, isNotNull);
      expect(s.mutations, isEmpty);
    });
    test('$app uncertain generate restores original key and body', () async {
      final s = VariantServer(app)..unavailable = true;
      var c = s.controller();
      await c.load();
      await c.showPreview();
      await c.generate();
      expect(c.pendingHere, isTrue);
      c = s.controller();
      await c.load();
      expect(c.pendingHere, isTrue);
      await c.resume();
      expect(s.mutations, hasLength(2));
      expect(s.mutations.first.body, s.mutations.last.body);
      expect(
        s.mutations.first.headers['idempotency-key'],
        s.mutations.last.headers['idempotency-key'],
      );
      expect(c.pending.value, isNull);
      expect(c.variants, hasLength(2));
    });
    test('$app revision conflict requires explicit reload', () async {
      final s = VariantServer(app)..conflict = true;
      s.product['status'] = 'DRAFT';
      final c = s.controller();
      await c.load();
      await c.changeStatus(c.variants.single);
      expect(c.conflict.value, isTrue);
      expect(c.pending.value, isNull);
      await c.changeStatus(c.variants.single);
      expect(s.mutations, hasLength(1));
      s.conflict = false;
      await c.load();
      await c.changeStatus(c.variants.single);
      expect(c.variants.single.status, 'ARCHIVED');
    });
    test('$app read-only and archived product cannot mutate', () async {
      final s = VariantServer(app)..permissions.remove('pim.variant.create');
      final c = s.controller();
      await c.load();
      await c.showPreview();
      expect(c.preview.value, isNull);
      s.product['status'] = 'ARCHIVED';
      await c.load();
      expect(c.writable, isFalse);
      expect(c.canChange(c.variants.single), isFalse);
    });
    test('$app unrelated pending request cannot be resumed here', () async {
      final s = VariantServer(app);
      final c = s.controller();
      await c.load();
      final other = c.fx.change(PimResource.products, {
        'name': 'نام',
      }, item: c.product);
      c.pending.value = other;
      expect(c.pendingHere, isFalse);
      await c.resume();
      expect(s.mutations, isEmpty);
    });
    test(
      '$app rejects over 100 combinations before requesting preview',
      () async {
        final server = VariantServer(app);
        final ids = List.generate(
          101,
          (i) => '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
        );
        server.product['variantAxes'] = [
          {'attributeId': attributeId, 'valueIds': ids},
        ];
        final c = server.controller();
        await c.load();
        await c.showPreview();
        expect(c.error.value, contains('۱۰۰'));
        expect(
          server.requests.where((r) => r.url.path.endsWith('/preview')),
          isEmpty,
        );
      },
    );
    test('$app empty axes preview is the server base combination', () async {
      final server = VariantServer(app);
      server.product['variantAxes'] = [];
      server.rows.clear();
      final c = server.controller();
      await c.load();
      await c.showPreview();
      expect(c.preview.value!.combinations.single, isEmpty);
      expect(c.title(c.preview.value!.combinations.single), 'تنوع پایه');
    });
    test('$app repeated generate tap sends one command', () async {
      final server = VariantServer(app);
      final c = server.controller();
      await c.load();
      await c.showPreview();
      await Future.wait([c.generate(), c.generate()]);
      expect(server.mutations, hasLength(1));
    });
    test('$app stale business context cannot generate', () async {
      final s = VariantServer(app);
      final c = s.controller();
      await c.load();
      await c.showPreview();
      BusinessContext.clear(app);
      await c.generate();
      expect(s.mutations, isEmpty);
    });
  }
}
