import 'remote_json.dart';

class ScopeAuthorization {
  final int businessId;
  final String membershipId, scopeType, scopeId;
  final String? personnelId;
  final Set<String> permissionCodes;
  final bool allowed;
  ScopeAuthorization.fromJson(Object? value) : this._(RemoteJson(value));
  ScopeAuthorization._(RemoteJson json)
    : businessId = json.number('businessId'),
      membershipId = json.text('membershipId'),
      scopeType = json.text('scopeType'),
      scopeId = json.text('scopeId'),
      personnelId = json.optionalText('personnelId'),
      permissionCodes = Set.unmodifiable(json.strings('permissionCodes')),
      allowed = json.flag('allowed');
}
