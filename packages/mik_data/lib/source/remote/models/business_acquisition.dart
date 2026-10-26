import 'remote_json.dart';

class BusinessAcquisition {
  final String sourceCode;
  final String? description;
  const BusinessAcquisition({required this.sourceCode, this.description});
  factory BusinessAcquisition.fromJson(Object? value) {
    final json = RemoteJson(value);
    return BusinessAcquisition(
      sourceCode: json.text('sourceCode'),
      description: json.optionalText('description'),
    );
  }
  Map<String, Object> toJson() => {
    'sourceCode': sourceCode,
    'description': ?description,
  };
}
