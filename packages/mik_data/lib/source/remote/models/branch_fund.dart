import 'package:uuid/uuid.dart';

import 'remote_json.dart';

class BranchFund {
  final String id, branchId, name, kind, status;
  final int businessId, balance, availableAmount;
  BranchFund.fromJson(Object? value) : this._(RemoteJson(value));
  BranchFund._(RemoteJson json)
    : id = json.text('fundId'),
      branchId = json.text('branchId'),
      name = json.text('name'),
      kind = json.text('kind'),
      status = json.text('status'),
      businessId = json.number('businessId'),
      balance = json.number('balance'),
      availableAmount = json.number('availableAmount') {
    if (![id, branchId].every((v) => Uuid.isValidUUID(fromString: v)) ||
        !['CASH', 'PETTY_CASH'].contains(kind) ||
        !['ACTIVE', 'ARCHIVED'].contains(status) ||
        [balance, availableAmount].any((v) => v < 0 || v > 9007199254740991)) {
      throw const FormatException('Invalid branch fund');
    }
  }
}
