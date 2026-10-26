import 'remote_json.dart';

class BranchAccess {
  final String branchAccessId;
  final int businessId;
  final String branchId;
  final String warehouseId;
  final bool canReadStock;
  final bool canReceiveStock;
  final bool canIssueStock;
  final String status;
  final int revision;
  const BranchAccess({
    required this.branchAccessId,
    required this.businessId,
    required this.branchId,
    required this.warehouseId,
    required this.canReadStock,
    required this.canReceiveStock,
    required this.canIssueStock,
    required this.status,
    required this.revision,
  });
  factory BranchAccess.fromJson(Object? value) {
    final json = RemoteJson(value);
    return BranchAccess(
      branchAccessId: json.text('branchAccessId'),
      businessId: json.number('businessId'),
      branchId: json.text('branchId'),
      warehouseId: json.text('warehouseId'),
      canReadStock: json.flag('canReadStock'),
      canReceiveStock: json.flag('canReceiveStock'),
      canIssueStock: json.flag('canIssueStock'),
      status: json.text('status'),
      revision: json.number('revision'),
    );
  }
}
