import 'remote_json.dart';

class BusinessSettings {
  final int businessId;
  final String defaultBranchId;
  final int schemaVersion;
  final int revision;
  const BusinessSettings({
    required this.businessId,
    required this.defaultBranchId,
    required this.schemaVersion,
    required this.revision,
  });
  factory BusinessSettings.fromJson(Object? value) {
    final json = RemoteJson(value);
    return BusinessSettings(
      businessId: json.number('businessId'),
      defaultBranchId: json.text('defaultBranchId'),
      schemaVersion: json.number('schemaVersion'),
      revision: json.number('revision'),
    );
  }
}
