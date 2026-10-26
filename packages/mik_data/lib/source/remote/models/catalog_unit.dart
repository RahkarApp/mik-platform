import 'remote_json.dart';

class CatalogUnit {
  final int id;
  final String name;
  const CatalogUnit({required this.id, required this.name});
  factory CatalogUnit.fromJson(Object? value) {
    final json = RemoteJson(value);
    return CatalogUnit(id: json.number('id'), name: json.text('name'));
  }
}
