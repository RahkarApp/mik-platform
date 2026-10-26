import 'package:uuid/uuid.dart';

import 'inventory_quantity.dart';
import 'remote_json.dart';

class StockBalance {
  final Map<String, dynamic> json;
  StockBalance(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value) {
    final row = RemoteJson(json);
    for (final key in ['balanceId', 'warehouseId', 'variantId', 'productId']) {
      if (!Uuid.isValidUUID(fromString: row.text(key))) {
        throw const FormatException('Invalid stock identity');
      }
    }
    if (row.number('revision') < 1 || row.number('unitId') < 1) {
      throw const FormatException('Invalid stock revision');
    }
    for (final key in buckets) {
      quantity(key);
    }
  }
  static const buckets = [
    'onHand',
    'damaged',
    'reserved',
    'allocationPending',
    'available',
    'inbound',
    'outbound',
  ];
  String get id => json['balanceId'] as String;
  String get variantId => json['variantId'] as String;
  String get productId => json['productId'] as String;
  int get revision => json['revision'] as int;
  String quantity(String key) =>
      InventoryQuantity.fromJson(json[key]).toString();
  static BigInt units(String value) {
    final parts = InventoryQuantity.fromJson(value).toString().split('.');
    return BigInt.parse(parts.first) * BigInt.from(1000000) +
        BigInt.parse((parts.length == 1 ? '' : parts.last).padRight(6, '0'));
  }
}

class StockMovement {
  final Map<String, dynamic> json;
  StockMovement(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value) {
    final row = RemoteJson(json);
    if (!Uuid.isValidUUID(fromString: row.text('movementId')) ||
        row.number('sequence') < 1) {
      throw const FormatException('Invalid stock movement');
    }
    DateTime.parse(row.text('createdAt'));
    row.text('reason');
    for (final side in ['before', 'after']) {
      final values = RemoteJson(json[side]);
      for (final key in StockBalance.buckets) {
        InventoryQuantity.fromJson(values.value[key]);
      }
    }
    delta;
  }
  int get sequence => json['sequence'] as int;
  String get id => json['movementId'] as String;
  String get delta {
    final value = RemoteJson(json['deltas']).text('deltaOnHand');
    InventoryQuantity.fromJson(
      value.startsWith('-') ? value.substring(1) : value,
    );
    return value;
  }
}
