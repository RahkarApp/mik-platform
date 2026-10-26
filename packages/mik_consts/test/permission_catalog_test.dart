import 'package:flutter_test/flutter_test.dart';
import 'package:mik_consts/permission_names.dart';

void main() {
  test('every permission has a unique name and spreadsheet position', () {
    final entries = PermissionCatalog.definitions;
    expect(entries.map((p) => p.name).toSet().length, entries.length);
    expect(entries.map((p) => p.legacyIndex).toSet().length, entries.length);
    for (final p in entries) {
      expect(p.legacyIndex, inInclusiveRange(1, 210));
      if (p.requiredName != null)
        expect(PermissionCatalog.byName, contains(p.requiredName));
    }
  });

  test('each individual old bit grants exactly its named permission', () {
    for (final p in PermissionCatalog.definitions) {
      final bits = List.filled(211, '0')..[p.legacyIndex] = '1';
      expect(PermissionCatalog.decode(bits.join()), {p.name});
    }
  });

  test('table indices for sell, buy, own and all are preserved', () {
    expect(
      PermissionCatalog.byLegacyIndex[26]!.name,
      PermissionsName.invoicesSellEdit,
    );
    expect(
      PermissionCatalog.byLegacyIndex[38]!.name,
      PermissionsName.invoicesSellEditAll,
    );
    expect(
      PermissionCatalog.byLegacyIndex[61]!.name,
      PermissionsName.invoicesBuyCreate,
    );
    expect(PermissionCatalog.byLegacyIndex[62], isNull);
    expect(
      PermissionCatalog.byLegacyIndex[63]!.name,
      PermissionsName.invoicesBuyView,
    );
    expect(
      PermissionCatalog.byLegacyIndex[70]!.name,
      PermissionsName.invoicesBuyDeleteAll,
    );
    expect(
      PermissionCatalog.byLegacyIndex[95]!.name,
      PermissionsName.costsDeleteAll,
    );
    expect(
      PermissionCatalog.byLegacyIndex[98]!.name,
      PermissionsName.chequesView,
    );
    expect(
      PermissionCatalog.byLegacyIndex[102]!.name,
      PermissionsName.chequesViewAll,
    );
  });

  test(
    'unchanged role roundtrip preserves reserved and future legacy bits',
    () {
      final original = List.filled(220, '1').join();
      expect(
        PermissionCatalog.encodeLegacy(
          PermissionCatalog.decode(original),
          original: original,
        ),
        original,
      );
      final changed = PermissionCatalog.decode(original)
        ..remove(PermissionsName.productsEdit);
      final expected = original.split('')..[4] = '0';
      expect(
        PermissionCatalog.encodeLegacy(changed, original: original),
        expected.join(),
      );
    },
  );

  test(
    'short, empty and malformed roles are safe and never grant unknown rights',
    () {
      expect(PermissionCatalog.decode(''), isEmpty);
      expect(PermissionCatalog.decode(null), isEmpty);
      expect(PermissionCatalog.decode('1'), isEmpty);
      expect(PermissionCatalog.decode('11'), {PermissionsName.productsMenu});
      expect(PermissionCatalog.decode('11x1'), isEmpty);
      expect(PermissionCatalog.decode('["unknown", "products.edit"]'), {
        PermissionsName.productsEdit,
      });
      expect(PermissionCatalog.decode('["products.edit", 1]'), isEmpty);
      expect(PermissionCatalog.decode('['), isEmpty);
    },
  );

  test('disabling a menu does not revoke unrelated migrated permissions', () {
    final selected = {PermissionsName.productsMenu, PermissionsName.productsEdit,
      PermissionsName.customersEdit};
    expect(PermissionCatalog.select(selected, PermissionsName.productsMenu, false),
        {PermissionsName.customersEdit});
  });

  test('named roles roundtrip and prerequisites are edited explicitly', () {
    final selected = PermissionCatalog.select(
      {},
      PermissionsName.productsPropertiesEdit,
      true,
    );
    expect(selected, {
      PermissionsName.productsPropertiesEdit,
      PermissionsName.productsMenu,
    });
    expect(
      PermissionCatalog.decode(PermissionCatalog.encodeNames(selected)),
      selected,
    );
    expect(
      PermissionCatalog.select(selected, PermissionsName.productsMenu, false),
      isEmpty,
    );
    expect(PermissionCatalog.decode('["products.properties.edit"]'), {
      PermissionsName.productsPropertiesEdit,
    });
  });
}
