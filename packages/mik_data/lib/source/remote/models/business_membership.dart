import 'remote_json.dart';

class BusinessMembership {
  final String membershipId;
  final int businessId;
  final String identityId;
  final String membershipType;
  final String? personnelId;
  final String status;
  final int revision;
  const BusinessMembership({
    required this.membershipId,
    required this.businessId,
    required this.identityId,
    required this.membershipType,
    required this.personnelId,
    required this.status,
    required this.revision,
  });
  factory BusinessMembership.fromJson(Object? value) {
    final json = RemoteJson(value);
    return BusinessMembership(
      membershipId: json.text('membershipId'),
      businessId: json.number('businessId'),
      identityId: json.text('identityId'),
      membershipType: json.text('membershipType'),
      personnelId: json.optionalText('personnelId'),
      status: json.text('status'),
      revision: json.number('revision'),
    );
  }
}
