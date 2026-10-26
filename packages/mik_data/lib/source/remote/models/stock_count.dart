import 'package:uuid/uuid.dart';

import 'inventory_quantity.dart';
import 'remote_json.dart';
import 'stock.dart';

class StockCountLine {
  final Map<String, dynamic> json;
  StockCountLine(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value) {
    final row = RemoteJson(json);
    for (final key in ['variantId', 'productId']) {
      if (!Uuid.isValidUUID(fromString: row.text(key))) {
        throw const FormatException('Invalid count item');
      }
    }
    if (row.number('expectedRevision') < 0 || row.number('unitId') < 1) {
      throw const FormatException('Invalid count snapshot');
    }
    for (final key in ['onHand', 'damaged', 'reserved', 'allocationPending']) {
      amount(key);
    }
    for (final key in ['countedOnHand', 'countedDamaged']) {
      if (json.containsKey(key)) amount(key);
    }
    if (counted &&
        StockBalance.units(amount('countedDamaged')) >
            StockBalance.units(amount('countedOnHand'))) {
      throw const FormatException('Damaged count exceeds physical');
    }
  }
  String get id => json['variantId'] as String;
  String amount(String key) => InventoryQuantity.fromJson(json[key]).toString();
  bool get counted =>
      json.containsKey('countedOnHand') && json.containsKey('countedDamaged');
  String difference(String counted, String original) {
    final units =
        StockBalance.units(counted) - StockBalance.units(amount(original));
    final absolute = units.abs(), scale = BigInt.from(1000000);
    final fraction = (absolute % scale)
        .toString()
        .padLeft(6, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '${units.isNegative ? '-' : ''}${absolute ~/ scale}${fraction.isEmpty ? '' : '.$fraction'}';
  }
}

class StockCount {
  final Map<String, dynamic> json;
  final List<StockCountLine> lines;
  StockCount(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value),
      lines = RemoteJson(value).items('lines', StockCountLine.new) {
    final row = RemoteJson(json);
    for (final key in ['countId', 'branchId', 'warehouseId']) {
      if (!Uuid.isValidUUID(fromString: row.text(key))) {
        throw const FormatException('Invalid count scope');
      }
    }
    if (!['OPEN', 'POSTED', 'CANCELLED'].contains(status) ||
        revision < 1 ||
        lines.isEmpty ||
        lines.length > 30 ||
        lines.map((l) => l.id).toSet().length != lines.length) {
      throw const FormatException('Invalid count record');
    }
    row.text('reason');
    DateTime.parse(row.text('createdAt'));
  }
  String get id => json['countId'] as String;
  String get status => json['status'] as String;
  int get revision => json['revision'] as int;
}
