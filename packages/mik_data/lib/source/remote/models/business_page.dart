import 'business_summary.dart';
import 'remote_json.dart';

class BusinessPage {
  final List<BusinessSummary> items;
  final int? nextCursor;
  const BusinessPage({required this.items, required this.nextCursor});
  factory BusinessPage.fromJson(Object? value) {
    final json = RemoteJson(value);
    return BusinessPage(
      items: json.items('items', BusinessSummary.fromJson),
      nextCursor: json.optionalNumber('nextCursor'),
    );
  }
}
