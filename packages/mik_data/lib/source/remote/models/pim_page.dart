import 'pim_record.dart';
import 'pim_resource.dart';
import 'remote_json.dart';

class PimPage {
  final int businessId;
  final List<PimRecord> items;
  final String? nextCursor;
  PimPage.fromJson(Object? value, PimResource resource)
    : this._(RemoteJson(value), resource);
  PimPage._(RemoteJson json, PimResource resource)
    : businessId = json.number('businessId'),
      items = json.items('items', resource.parse),
      nextCursor = json.optionalText('nextCursor') {
    if (items.any((item) => item.businessId != businessId)) {
      throw const FormatException('Unexpected PIM business');
    }
  }
}
