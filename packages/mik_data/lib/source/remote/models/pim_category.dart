import 'pim_record.dart';
import 'remote_json.dart';

class PimCategory extends PimRecord {
  @override
  final String id, name;
  final String? parentId, description, templateCode;
  final String source;
  PimCategory.fromJson(Object? value) : this._(RemoteJson(value));
  PimCategory._(super.json)
    : id = json.text('categoryId'),
      name = json.text('name'),
      parentId = json.optionalText('parentId'),
      description = json.optionalText('description'),
      source = json.text('source'),
      templateCode = json.optionalText('templateCode');
}
