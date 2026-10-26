/// Inventory HTTP quantities are decimal strings, exact to six decimal places.
class InventoryQuantity {
  static final _scale = BigInt.from(1000000);
  final BigInt _units;
  const InventoryQuantity._(this._units);

  factory InventoryQuantity.fromJson(Object? value) {
    if (value is! String ||
        !RegExp(r'^(0|[1-9]\d{0,9})(\.\d{1,6})?$').hasMatch(value)) {
      throw const FormatException('Invalid inventory quantity');
    }
    final parts = value.split('.');
    final units =
        BigInt.parse(parts[0]) * _scale +
        BigInt.parse((parts.length == 1 ? '' : parts[1]).padRight(6, '0'));
    if (units > BigInt.parse('9007199254740991')) {
      throw const FormatException(
        'Inventory quantity exceeds server precision',
      );
    }
    return InventoryQuantity._(units);
  }

  InventoryQuantity operator +(InventoryQuantity other) =>
      InventoryQuantity._(_units + other._units);
  bool get isZero => _units == BigInt.zero;
  @override
  String toString() {
    final fraction = (_units % _scale)
        .toString()
        .padLeft(6, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '${_units ~/ _scale}${fraction.isEmpty ? '' : '.$fraction'}';
  }
}
