import 'catalog_category.dart';
import 'catalog_unit.dart';
import 'remote_json.dart';

class ProductCatalog {
  final int version;
  final List<CatalogCategory> items;
  final List<CatalogUnit> units;
  final String? nextCursor;
  const ProductCatalog({
    required this.version,
    required this.items,
    required this.units,
    required this.nextCursor,
  });
  factory ProductCatalog.fromJson(Object? value) {
    final json = RemoteJson(value);
    return ProductCatalog(
      version: json.number('version'),
      items: json.items('items', CatalogCategory.fromJson),
      units: json.items('units', CatalogUnit.fromJson),
      nextCursor: json.optionalText('nextCursor'),
    );
  }
}
