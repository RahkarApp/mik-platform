import 'remote_json.dart';

class BusinessAuthorization {
  final int businessId;
  final int catalogVersion;
  final List<String> permissionCodes;
  const BusinessAuthorization({
    required this.businessId,
    required this.catalogVersion,
    required this.permissionCodes,
  });
  factory BusinessAuthorization.fromJson(Object? value) {
    final json = RemoteJson(value);
    return BusinessAuthorization(
      businessId: json.number('businessId'),
      catalogVersion: json.number('catalogVersion'),
      permissionCodes: json.strings('permissionCodes'),
    );
  }
}
