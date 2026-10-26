import 'remote_json.dart';

class BusinessBranch {
  final String branchId;
  final int businessId;
  final String name;
  final String? defaultWarehouseId;
  final String status;
  final int revision;
  final String? code, phone;
  final Map<String, dynamic>? address;
  const BusinessBranch({
    required this.branchId,
    required this.businessId,
    required this.name,
    required this.defaultWarehouseId,
    required this.status,
    required this.revision,
    this.code,
    this.phone,
    this.address,
  });
  factory BusinessBranch.fromJson(Object? value) {
    final json = RemoteJson(value);
    return BusinessBranch(
      branchId: json.text('branchId'),
      businessId: json.number('businessId'),
      name: json.text('name'),
      defaultWarehouseId: json.optionalText('defaultWarehouseId'),
      status: json.text('status'),
      revision: json.number('revision'),
      code: json.optionalText('code'),
      phone: json.optionalText('phone'),
      address: json.value['address'] == null
          ? null
          : Map.unmodifiable(RemoteJson(json.value['address']).value),
    );
  }
}
