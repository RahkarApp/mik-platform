import 'remote_json.dart';

class CatalogCategory {
  final String id;
  final String name;
  final String? parent;
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.parent,
  });
  factory CatalogCategory.fromJson(Object? value) {
    final json = RemoteJson(value);
    return CatalogCategory(
      id: json.text('id'),
      name: json.text('name'),
      parent: json.optionalText('parent'),
    );
  }
}
