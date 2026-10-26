import 'remote_json.dart';

class PimOption {
  final String valueId, name;
  final String? code, colorHex;
  final bool active;
  const PimOption({
    required this.valueId,
    required this.name,
    this.code,
    this.colorHex,
    this.active = true,
  });
  factory PimOption.fromJson(Object? value) {
    final json = RemoteJson(value);
    return PimOption(
      valueId: json.text('valueId'),
      name: json.text('name'),
      code: json.optionalText('code'),
      colorHex: json.optionalText('colorHex'),
      active: json.flag('active'),
    );
  }
  Map<String, Object> toJson() => {
    'valueId': valueId,
    'name': name,
    'code': ?code,
    'colorHex': ?colorHex,
    'active': active,
  };
}
