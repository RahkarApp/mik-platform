import 'pim_record.dart';
import 'pim_resource.dart';
import 'pim_variant.dart';
import 'remote_json.dart';

class PimResult {
  final int businessId;
  final bool replayed;
  final PimRecord? item;
  final PimVariant? baseVariant;
  final List<PimVariant> variants;
  final int? importedCount, createdCount, catalogVersion;
  PimResult.fromJson(Object? value, {PimResource? resource})
    : this._(RemoteJson(value), resource);
  PimResult._(RemoteJson json, PimResource? resource)
    : businessId = json.number('businessId'),
      replayed = json.flag('replayed'),
      item = resource?.parse(json.value['item']),
      baseVariant = json.value['baseVariant'] == null
          ? null
          : PimVariant.fromJson(json.value['baseVariant']),
      variants = json.value['items'] == null
          ? const []
          : json.items('items', PimVariant.fromJson),
      importedCount = json.optionalNumber('importedCount'),
      createdCount = json.optionalNumber('createdCount'),
      catalogVersion = json.optionalNumber('catalogVersion') {
    if (item != null && item!.businessId != businessId ||
        baseVariant != null && baseVariant!.businessId != businessId ||
        variants.any((v) => v.businessId != businessId)) {
      throw const FormatException('Unexpected mutation business');
    }
  }
}
