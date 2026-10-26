import 'pim_actor.dart';
import 'remote_json.dart';

abstract class PimRecord {
  final int businessId, revision;
  final String status;
  final PimActor createdBy;
  String get id;
  String get name;
  PimRecord(RemoteJson json)
    : businessId = json.number('businessId'),
      revision = json.number('revision'),
      status = json.text('status'),
      createdBy = PimActor.fromJson(json.value['createdBy']) {
    if (revision < 1) throw const FormatException('Invalid PIM revision');
  }
}
