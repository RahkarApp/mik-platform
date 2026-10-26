import 'inventory_quantity.dart';
import 'remote_json.dart';

class InventoryAvailability {
  final int businessId;
  final String fulfillmentMode;
  final List<VariantAvailability> items;
  InventoryAvailability.fromJson(Object? value) : this._(RemoteJson(value));
  InventoryAvailability._(RemoteJson json)
    : businessId = json.number('businessId'),
      fulfillmentMode = json.text('fulfillmentMode'),
      items = json.items('items', VariantAvailability.fromJson) {
    if (!['SINGLE_WAREHOUSE', 'MULTI_WAREHOUSE'].contains(fulfillmentMode)) {
      throw const FormatException('Invalid inventory fulfillment mode');
    }
  }
}

class VariantAvailability {
  final String variantId, productId;
  final int unitId;
  final bool active;
  final InventoryQuantity available;
  final List<WarehouseAvailability> warehouses;
  VariantAvailability.fromJson(Object? value) : this._(RemoteJson(value));
  VariantAvailability._(RemoteJson json)
    : variantId = json.text('variantId'),
      productId = json.text('productId'),
      unitId = json.number('unitId'),
      active = json.flag('active'),
      available = InventoryQuantity.fromJson(json.value['available']),
      warehouses = json.items('warehouses', WarehouseAvailability.fromJson);
}

class WarehouseAvailability {
  final String warehouseId;
  final InventoryQuantity available;
  final bool blockedForCount;
  final int revision;
  WarehouseAvailability.fromJson(Object? value) : this._(RemoteJson(value));
  WarehouseAvailability._(RemoteJson json)
    : warehouseId = json.text('warehouseId'),
      available = InventoryQuantity.fromJson(json.value['available']),
      blockedForCount = json.flag('blockedForCount'),
      revision = json.number('revision') {
    if (revision < 0) throw const FormatException('Invalid inventory revision');
  }
}
