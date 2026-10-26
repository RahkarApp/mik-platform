import 'remote_json.dart';

class BusinessWarehouse {
  final String warehouseId;
  final int businessId;
  final String name;
  final String status;
  final int revision;
  const BusinessWarehouse({
    required this.warehouseId,
    required this.businessId,
    required this.name,
    required this.status,
    required this.revision,
  });
  factory BusinessWarehouse.fromJson(Object? value) {
    final json = RemoteJson(value);
    return BusinessWarehouse(
      warehouseId: json.text('warehouseId'),
      businessId: json.number('businessId'),
      name: json.text('name'),
      status: json.text('status'),
      revision: json.number('revision'),
    );
  }
}
