import 'pim_option.dart';
import 'pim_record.dart';
import 'remote_json.dart';

class PimAttribute extends PimRecord {
  @override
  final String id, name;
  final String kind, dataType;
  final bool usableForVariant;
  final int? unitId;
  final List<PimOption> values;
  PimAttribute.fromJson(Object? value) : this._(RemoteJson(value));
  PimAttribute._(super.json)
    : id = json.text('attributeId'),
      name = json.text('name'),
      kind = json.text('kind'),
      dataType = json.text('dataType'),
      usableForVariant = json.flag('usableForVariant'),
      unitId = json.optionalNumber('unitId'),
      values = json.items('values', PimOption.fromJson);
}
