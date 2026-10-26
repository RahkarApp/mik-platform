import 'remote_json.dart';

class PimAxis {
  final String attributeId;
  final List<String> valueIds;
  const PimAxis({required this.attributeId, required this.valueIds});
  factory PimAxis.fromJson(Object? value) {
    final json = RemoteJson(value);
    return PimAxis(
      attributeId: json.text('attributeId'),
      valueIds: json.strings('valueIds'),
    );
  }
  Map<String, Object> toJson() => {
    'attributeId': attributeId,
    'valueIds': valueIds,
  };
}
