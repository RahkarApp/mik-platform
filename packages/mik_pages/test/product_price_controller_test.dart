import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/business_context.dart';

import '../../mik_data/test/support/pim_fixtures.dart';
import 'support/product_price_fixtures.dart';

void main() {
  tearDown(() {
    BusinessContext.clear('mik');
    BusinessContext.clear('mikyar');
  });
  for (final app in ['mik', 'mikyar']) {
    test(
      '$app loads product-scoped titles and overrides and accepts explicit zero',
      () async {
        final server = PriceServer(app);
        final c = server.controller();
        await c.load();
        expect(c.loadError.value, isNull);
        expect(c.prices, hasLength(1));
        final command = c.priceCommand(
          name: 'عمده',
          input: '۰ تومان',
          isDefault: false,
        );
        expect(await c.save(command), isTrue);
        expect(jsonDecode(server.mutations.single.body), {
          'productId': productId,
          'name': 'عمده',
          'amount': 0,
          'validFrom': null,
          'validUntil': null,
        });
        expect(server.mutations.single.headers['x-app-id'], app);
      },
    );
    test(
      '$app changing default is explicit and reloads the previous title revision',
      () async {
        final server = PriceServer(app);
        final c = server.controller();
        await c.load();
        expect(
          await c.save(
            c.priceCommand(name: 'جدید', input: '250', isDefault: true),
          ),
          isTrue,
        );
        await c.load();
        expect(c.prices.singleWhere((p) => p.id == priceId).isDefault, isFalse);
        expect(c.prices.singleWhere((p) => p.id == priceId).revision, 4);
        expect(
          c.prices.singleWhere((p) => p.id == newPriceId).isDefault,
          isTrue,
        );
      },
    );
    test('$app archives a non-default price with its revision', () async {
      final server = PriceServer(app)..permissions.add('pim.price.delete');
      server.prices.add({
        ...fixturePim(PimResource.prices, id: newPriceId),
        'isDefault': false,
      });
      final c = server.controller();
      await c.load();
      expect(c.canArchive(c.prices.singleWhere((p) => p.isDefault)), isFalse);
      final price = c.prices.singleWhere((p) => p.id == newPriceId);
      expect(await c.save(c.archiveCommand(price)), isTrue);
      expect(jsonDecode(server.mutations.single.body), {
        'status': 'ARCHIVED',
        'expectedRevision': price.revision,
      });
    });
    test(
      '$app unchanged default does not demand default-update permission',
      () async {
        final server = PriceServer(app)
          ..permissions.remove('pim.price.default.update');
        final c = server.controller();
        await c.load();
        expect(
          await c.save(
            c.priceCommand(
              item: c.prices.single,
              name: 'فروش',
              input: '200',
              isDefault: true,
            ),
          ),
          isTrue,
        );
        expect(jsonDecode(server.mutations.single.body), {
          'amount': 200,
          'expectedRevision': 3,
        });
      },
    );
    test(
      '$app choosing a default without its grant sends no mutation',
      () async {
        final server = PriceServer(app)
          ..permissions.remove('pim.price.default.update');
        final c = server.controller();
        await c.load();
        expect(
          await c.save(
            c.priceCommand(name: 'نام', input: '1', isDefault: true),
          ),
          isFalse,
        );
        expect(server.mutations, isEmpty);
      },
    );
    test('$app other creators need the update-all grant', () async {
      final server = PriceServer(app);
      server.prices[0] = fixturePim(
        PimResource.prices,
        creator: '99999999-9999-4999-8999-999999999999',
      );
      final c = server.controller();
      await c.load();
      expect(c.canEdit(c.prices.single), isFalse);
      expect(
        () => c.priceCommand(
          item: c.prices.single,
          name: 'فروش',
          input: '1',
          isDefault: true,
        ),
        throwsA(anything),
      );
      server.permissions.add('pim.price.update.all');
      await c.load();
      expect(c.canEdit(c.prices.single), isTrue);
    });
    test(
      '$app time windows serialize exact UTC instants and can be cleared',
      () async {
        final server = PriceServer(app);
        final c = server.controller();
        await c.load();
        final from = DateTime.parse('2027-01-01T10:15:00+03:30'),
            until = DateTime.parse('2027-01-02T12:00:00+03:30');
        final cmd = c.priceCommand(
          name: 'زمان‌دار',
          input: '10',
          isDefault: false,
          from: from,
          until: until,
        );
        expect(cmd.body['validFrom'], '2027-01-01T06:45:00.000Z');
        expect(cmd.body['validUntil'], '2027-01-02T08:30:00.000Z');
        expect(await c.save(cmd), isTrue);
        await c.load();
        final price = c.prices.singleWhere((p) => p.id == newPriceId);
        expect(
          await c.save(
            c.priceCommand(
              item: price,
              name: price.name,
              input: '10',
              isDefault: false,
            ),
          ),
          isTrue,
        );
        expect(jsonDecode(server.mutations.last.body), {
          'validFrom': null,
          'validUntil': null,
          'expectedRevision': price.revision,
        });
      },
    );
    test(
      '$app blank invalid amounts and reversed validity make no request',
      () async {
        final server = PriceServer(app);
        final c = server.controller();
        await c.load();
        for (final amount in ['', '-1', '1.5', '9000000000001']) {
          expect(
            () => c.priceCommand(name: 'فروش', input: amount, isDefault: false),
            throwsStateError,
          );
        }
        expect(
          () => c.priceCommand(
            name: 'فروش',
            input: '1',
            isDefault: false,
            from: DateTime.utc(2027, 1, 2),
            until: DateTime.utc(2027, 1, 1),
          ),
          throwsStateError,
        );
        expect(server.mutations, isEmpty);
      },
    );
    test(
      '$app override creation and update preserve immutable references',
      () async {
        final server = PriceServer(app);
        final c = server.controller();
        await c.load();
        expect(
          await c.save(
            c.overrideCommand(
              priceId: priceId,
              variantId: variantId,
              input: '0',
            ),
          ),
          isTrue,
        );
        expect(jsonDecode(server.mutations.single.body), {
          'productPriceId': priceId,
          'variantId': variantId,
          'amount': 0,
        });
        await c.load();
        final value = c.overrides.single;
        expect(
          await c.save(
            c.overrideCommand(
              item: value,
              priceId: priceId,
              variantId: variantId,
              input: '90',
            ),
          ),
          isTrue,
        );
        expect(jsonDecode(server.mutations.last.body), {
          'amount': 90,
          'expectedRevision': value.revision,
        });
        expect(
          () => c.overrideCommand(
            item: value,
            priceId: newPriceId,
            variantId: variantId,
            input: '1',
          ),
          throwsA(anything),
        );
      },
    );
    test(
      '$app lost response replays the saved command after reopening',
      () async {
        final server = PriceServer(app)..unavailable = true;
        final c = server.controller();
        await c.load();
        expect(
          await c.save(
            c.priceCommand(name: 'ثبت اصلی', input: '12', isDefault: false),
          ),
          isFalse,
        );
        final original = server.mutations.single;
        final reopened = server.controller();
        await reopened.load();
        expect(reopened.pendingHere, isTrue);
        await reopened.resume();
        expect(server.mutations.last.body, original.body);
        expect(
          server.mutations.last.headers['idempotency-key'],
          original.headers['idempotency-key'],
        );
        expect(server.prices, hasLength(2));
      },
    );
    test('$app revision conflict stops automatic resubmission', () async {
      final server = PriceServer(app)..revisionConflict = true;
      final c = server.controller();
      await c.load();
      final command = c.priceCommand(
        item: c.prices.single,
        name: 'فروش',
        input: '50',
        isDefault: true,
      );
      expect(await c.save(command), isFalse);
      expect(c.conflict.value, isTrue);
      expect(await c.save(command), isFalse);
      expect(server.mutations, hasLength(1));
    });
    test('$app wrong-product data and stale sessions fail closed', () async {
      final server = PriceServer(app);
      server.prices[0]['productId'] = categoryId;
      final c = server.controller();
      await c.load();
      expect(c.loadError.value, isNotNull);
      expect(c.prices, isEmpty);
      server.prices[0]['productId'] = productId;
      await c.load();
      final command = c.priceCommand(name: 'نام', input: '1', isDefault: false);
      BusinessContext.clear(app);
      expect(await c.save(command), isFalse);
      expect(server.mutations, isEmpty);
    });
  }
}
