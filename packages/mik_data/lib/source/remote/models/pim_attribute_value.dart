import 'remote_json.dart';

class PimAttributeValue {
  final String attributeId;
  final String? textValue;
  final num? numberValue;
  final bool? booleanValue;
  final List<String>? valueIds;
  const PimAttributeValue({
    required this.attributeId,
    this.textValue,
    this.numberValue,
    this.booleanValue,
    this.valueIds,
  });
  factory PimAttributeValue.fromJson(Object? value) {
    final json = RemoteJson(value);
    final number = json.value['numberValue'];
    final flag = json.value['booleanValue'];
    if (number != null && number is! num || flag != null && flag is! bool) {
      throw const FormatException('Invalid typed attribute value');
    }
    return PimAttributeValue(
      attributeId: json.text('attributeId'),
      textValue: json.optionalText('textValue'),
      numberValue: number as num?,
      booleanValue: flag as bool?,
      valueIds: json.value['valueIds'] == null
          ? null
          : json.strings('valueIds'),
    );
  }
  Map<String, Object> toJson() => {
    'attributeId': attributeId,
    'textValue': ?textValue,
    'numberValue': ?numberValue,
    'booleanValue': ?booleanValue,
    'valueIds': ?valueIds,
  };
}
