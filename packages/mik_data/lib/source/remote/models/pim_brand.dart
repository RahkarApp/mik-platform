import 'pim_record.dart';
import 'remote_json.dart';

class PimBrand extends PimRecord {
  @override
  final String id, name;
  final String? latinName, description, website;
  PimBrand.fromJson(Object? value) : this._(RemoteJson(value));
  PimBrand._(super.json)
    : id = json.text('brandId'),
      name = json.text('name'),
      latinName = json.optionalText('latinName'),
      description = json.optionalText('description'),
      website = json.optionalText('website');
}
