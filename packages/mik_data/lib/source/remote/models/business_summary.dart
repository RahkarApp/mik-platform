import 'remote_json.dart';

class BusinessSummary {
  final int businessId;
  final String name;
  final String membershipId;
  final String membershipType;
  const BusinessSummary({
    required this.businessId,
    required this.name,
    required this.membershipId,
    required this.membershipType,
  });
  factory BusinessSummary.fromJson(Object? value) {
    final json = RemoteJson(value);
    return BusinessSummary(
      businessId: json.number('businessId'),
      name: json.text('name'),
      membershipId: json.text('membershipId'),
      membershipType: json.text('membershipType'),
    );
  }
}
