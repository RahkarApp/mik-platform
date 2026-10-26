import 'remote_json.dart';

class PimOptionPair {
  final String attributeId, valueId;
  const PimOptionPair({required this.attributeId, required this.valueId});
  factory PimOptionPair.fromJson(Object? value) {
    final json = RemoteJson(value);
    return PimOptionPair(
      attributeId: json.text('attributeId'),
      valueId: json.text('valueId'),
    );
  }
  Map<String, Object> toJson() => {
    'attributeId': attributeId,
    'valueId': valueId,
  };
}
