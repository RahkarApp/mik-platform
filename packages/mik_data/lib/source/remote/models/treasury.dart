import 'package:uuid/uuid.dart';

import 'remote_json.dart';

class TreasuryFund {
  final Map<String, dynamic> json;
  final String id, name, kind, status;
  final String? branchId, bankName, accountNumber, iban;
  final int businessId, revision, balance, availableAmount;
  TreasuryFund.fromJson(Object? value) : this._(RemoteJson(value));
  TreasuryFund._(RemoteJson data)
    : json = Map.unmodifiable(data.value),
      id = data.text('fundId'),
      name = data.text('name'),
      kind = data.text('kind'),
      status = data.text('status'),
      branchId = data.optionalText('branchId'),
      bankName = data.optionalText('bankName'),
      accountNumber = data.optionalText('accountNumber'),
      iban = data.optionalText('iban'),
      businessId = data.number('businessId'),
      revision = data.number('revision'),
      balance = data.number('balance'),
      // Mutations return the stored record; only queries decorate availableAmount.
      availableAmount = data.value.containsKey('availableAmount')
          ? data.number('availableAmount')
          : data.number('balance') - data.number('heldAmount') {
    final held = data.number('heldAmount');
    if (!Uuid.isValidUUID(fromString: id) ||
        revision < 1 ||
        !['BANK', 'CASH', 'PETTY_CASH'].contains(kind) ||
        !['ACTIVE', 'ARCHIVED'].contains(status) ||
        (kind == 'BANK'
            ? branchId != null
            : branchId == null || !Uuid.isValidUUID(fromString: branchId!)) ||
        [
          balance,
          held,
          availableAmount,
        ].any((v) => v < 0 || v > 9007199254740991) ||
        availableAmount != balance - held) {
      throw const FormatException('Invalid treasury fund');
    }
  }
}

class TreasuryTerminal {
  final Map<String, dynamic> json;
  final String id, name, branchId, fundId, status;
  final String? terminalNumber, merchantNumber, providerName;
  final int businessId, revision;
  TreasuryTerminal.fromJson(Object? value) : this._(RemoteJson(value));
  TreasuryTerminal._(RemoteJson data)
    : json = Map.unmodifiable(data.value),
      id = data.text('terminalId'),
      name = data.text('name'),
      branchId = data.text('branchId'),
      fundId = data.text('fundId'),
      status = data.text('status'),
      businessId = data.number('businessId'),
      revision = data.number('revision'),
      terminalNumber = data.optionalText('terminalNumber'),
      merchantNumber = data.optionalText('merchantNumber'),
      providerName = data.optionalText('providerName') {
    if (![
          id,
          branchId,
          fundId,
        ].every((id) => Uuid.isValidUUID(fromString: id)) ||
        revision < 1 ||
        !['ACTIVE', 'ARCHIVED'].contains(status)) {
      throw const FormatException('Invalid treasury terminal');
    }
  }
}
