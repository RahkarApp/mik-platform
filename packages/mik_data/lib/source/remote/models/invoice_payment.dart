import 'package:uuid/uuid.dart';

import 'invoice_read.dart';
import 'remote_json.dart';

class InvoicePartyPayment {
  final String id, partyId, partyType, branchId, method, direction, status;
  final int businessId, amount;
  InvoicePartyPayment.fromJson(Object? value) : this._(RemoteJson(value));
  InvoicePartyPayment._(RemoteJson json)
    : id = json.text('paymentId'),
      partyId = json.text('partyId'),
      partyType = json.text('partyType'),
      branchId = json.text('branchId'),
      method = json.text('method'),
      direction = json.text('direction'),
      status = json.text('status'),
      businessId = json.number('businessId'),
      amount = RemoteInvoiceSummary.money(json.value['amount']) {
    if (![
          id,
          partyId,
          branchId,
        ].every((v) => Uuid.isValidUUID(fromString: v)) ||
        !['CUSTOMER', 'SUPPLIER'].contains(partyType) ||
        ![
          'CASH',
          'CARD',
          'BANK_TRANSFER',
          'CHEQUE',
          'ONLINE',
        ].contains(method) ||
        !['IN', 'OUT'].contains(direction) ||
        amount == 0 ||
        ![
          'PENDING',
          'CONFIRMED',
          'BOUNCED',
          'RETURNED',
          'REVERSED',
        ].contains(status)) {
      throw const FormatException('Invalid party payment');
    }
  }
}

class InvoiceSettlementSource {
  final String id, partyId, partyType, kind, referenceId, status;
  final String? restrictedRootId;
  final int businessId, amount, usedAmount;
  int get available => amount - usedAmount;
  InvoiceSettlementSource.fromJson(Object? value) : this._(RemoteJson(value));
  InvoiceSettlementSource._(RemoteJson json)
    : id = json.text('sourceId'),
      partyId = json.text('partyId'),
      partyType = json.text('partyType'),
      kind = json.text('kind'),
      referenceId = json.text('referenceId'),
      status = json.text('status'),
      restrictedRootId = json.optionalText('restrictedRootInvoiceId'),
      businessId = json.number('businessId'),
      amount = RemoteInvoiceSummary.money(json.value['amount']),
      usedAmount = RemoteInvoiceSummary.money(json.value['usedAmount']) {
    if (![
          id,
          partyId,
          referenceId,
          ?restrictedRootId,
        ].every((v) => Uuid.isValidUUID(fromString: v)) ||
        !['CUSTOMER', 'SUPPLIER'].contains(partyType) ||
        !['PAYMENT', 'CREDIT_NOTE'].contains(kind) ||
        !['ACTIVE', 'REVERSED'].contains(status) ||
        usedAmount > amount) {
      throw const FormatException('Invalid settlement source');
    }
  }
}

class InvoiceSettlementDocument {
  final String id, rootId, number, partyId, partyType, branchId, status, type;
  final int businessId, total, settled;
  int get remaining => total > settled ? total - settled : 0;
  InvoiceSettlementDocument.fromJson(Object? value) : this._(RemoteJson(value));
  InvoiceSettlementDocument._(RemoteJson json)
    : id = json.text('invoiceId'),
      rootId = json.text('rootInvoiceId'),
      number = json.text('number'),
      partyId = json.text('partyId'),
      partyType = json.text('partyType'),
      branchId = json.text('branchId'),
      status = json.text('status'),
      type = json.text('type'),
      businessId = json.number('businessId'),
      total = RemoteInvoiceSummary.money(
        RemoteJson(json.value['totals']).value['total'],
      ),
      settled = RemoteInvoiceSummary.money(json.value['settledAmount']) {
    if (![
          id,
          rootId,
          partyId,
          branchId,
        ].every((v) => Uuid.isValidUUID(fromString: v)) ||
        !['SALE', 'PRESALE', 'PURCHASE'].contains(type) ||
        ![
          'DRAFT',
          'ISSUED',
          'CANCELLED',
          'EXPIRED',
          'CONVERTED',
        ].contains(status)) {
      throw const FormatException('Invalid settlement document');
    }
  }
}

class InvoicePaymentDetail {
  final InvoicePartyPayment payment;
  final Map<String, dynamic> json;
  final int revision;
  final int? financialVersion;
  final String purpose;
  final String? note, reference;
  final Map<String, dynamic>? routing;
  InvoicePaymentDetail.fromJson(Object? value) : this._(RemoteJson(value));
  InvoicePaymentDetail._(RemoteJson data)
    : payment = InvoicePartyPayment.fromJson(data.value),
      json = Map.unmodifiable(data.value),
      revision = data.number('revision'),
      financialVersion = data.optionalNumber('financialVersion'),
      purpose = data.text('purpose'),
      note = data.optionalText('note'),
      reference = data.optionalText('transactionReference'),
      routing = data.value['routing'] == null
          ? null
          : Map.unmodifiable(RemoteJson(data.value['routing']).value) {
    if (revision < 1 ||
        !['SETTLEMENT', 'REFUND', 'REVERSAL'].contains(purpose) ||
        routing != null &&
            (!Uuid.isValidUUID(
                  fromString: RemoteJson(routing).text('fundId'),
                ) ||
                routing!['terminalId'] != null &&
                    !Uuid.isValidUUID(
                      fromString: RemoteJson(routing).text('terminalId'),
                    ))) {
      throw const FormatException('Invalid payment detail');
    }
  }
  bool get reversible =>
      payment.status == 'CONFIRMED' &&
      purpose != 'REVERSAL' &&
      financialVersion == 2 &&
      routing != null &&
      ['CASH', 'CARD', 'BANK_TRANSFER'].contains(payment.method);
}

class InvoiceSettlementAllocation {
  final Map<String, dynamic> json;
  final String id, partyId, partyType, sourceId, reason;
  final String? invoiceId, refundPaymentId;
  final int businessId, revision, amount, reversedAmount;
  int get activeAmount => amount - reversedAmount;
  InvoiceSettlementAllocation.fromJson(Object? value)
    : this._(RemoteJson(value));
  InvoiceSettlementAllocation._(RemoteJson data)
    : json = Map.unmodifiable(data.value),
      id = data.text('allocationId'),
      partyId = data.text('partyId'),
      partyType = data.text('partyType'),
      sourceId = data.text('sourceId'),
      reason = data.text('reason'),
      invoiceId = data.optionalText('invoiceId'),
      refundPaymentId = data.optionalText('refundPaymentId'),
      businessId = data.number('businessId'),
      revision = data.number('revision'),
      amount = RemoteInvoiceSummary.money(data.value['amount']),
      reversedAmount = RemoteInvoiceSummary.money(
        data.value['reversedAmount'],
      ) {
    if (![
          id,
          partyId,
          sourceId,
          ?invoiceId,
          ?refundPaymentId,
        ].every((v) => Uuid.isValidUUID(fromString: v)) ||
        !['CUSTOMER', 'SUPPLIER'].contains(partyType) ||
        revision < 1 ||
        amount == 0 ||
        reversedAmount > amount ||
        (invoiceId == null) == (refundPaymentId == null)) {
      throw const FormatException('Invalid settlement allocation');
    }
  }
}
