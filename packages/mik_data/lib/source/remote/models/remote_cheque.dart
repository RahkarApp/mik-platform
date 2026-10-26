import 'package:uuid/uuid.dart';

import 'remote_json.dart';
import 'invoice_read.dart';

class RemoteCheque {
  final Map<String, dynamic> json;
  final String id,
      paymentId,
      partyId,
      partyType,
      branchId,
      direction,
      bankName,
      number,
      status;
  final String? sayadId, drawerName;
  final DateTime dueAt;
  final int businessId, revision, amount;
  RemoteCheque.fromJson(Object? value) : this._(RemoteJson(value));
  RemoteCheque._(RemoteJson data)
    : json = Map.unmodifiable(data.value),
      id = data.text('chequeId'),
      paymentId = data.text('paymentId'),
      partyId = data.text('partyId'),
      partyType = data.text('partyType'),
      branchId = data.text('branchId'),
      direction = data.text('direction'),
      bankName = data.text('bankName'),
      number = data.text('number'),
      status = data.text('status'),
      sayadId = data.optionalText('sayadId'),
      drawerName = data.optionalText('drawerName'),
      dueAt = DateTime.parse(data.text('dueAt')),
      businessId = data.number('businessId'),
      revision = data.number('revision'),
      amount = RemoteInvoiceSummary.money(data.value['amount']) {
    if (![
          id,
          paymentId,
          partyId,
          branchId,
        ].every((v) => Uuid.isValidUUID(fromString: v)) ||
        revision < 1 ||
        amount == 0 ||
        !['IN', 'OUT'].contains(direction) ||
        !['CUSTOMER', 'SUPPLIER'].contains(partyType) ||
        !['PENDING', 'CONFIRMED', 'BOUNCED', 'RETURNED'].contains(status) ||
        !dueAt.isUtc ||
        sayadId != null && !RegExp(r'^\d{16}$').hasMatch(sayadId!)) {
      throw const FormatException('Invalid cheque');
    }
  }
}
