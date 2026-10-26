import 'remote_json.dart';

class PimActor {
  final String type;
  final String? identityId, membershipId, personnelId;
  PimActor.fromJson(Object? value) : this._(RemoteJson(value));
  PimActor._(RemoteJson json)
    : type = json.text('type'),
      identityId = json.optionalText('identityId'),
      membershipId = json.optionalText('membershipId'),
      personnelId = json.optionalText('personnelId');
}
