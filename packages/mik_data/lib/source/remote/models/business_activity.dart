import 'remote_json.dart';

class BusinessActivity {
  final String fieldCode;
  final List<String> subfieldCodes;
  BusinessActivity({
    required this.fieldCode,
    required List<String> subfieldCodes,
  }) : subfieldCodes = List.unmodifiable(subfieldCodes);
  factory BusinessActivity.fromJson(Object? value) {
    final json = RemoteJson(value);
    return BusinessActivity(
      fieldCode: json.text('fieldCode'),
      subfieldCodes: json.strings('subfieldCodes'),
    );
  }
  Map<String, Object> toJson() => {
    'fieldCode': fieldCode,
    'subfieldCodes': subfieldCodes,
  };
}
