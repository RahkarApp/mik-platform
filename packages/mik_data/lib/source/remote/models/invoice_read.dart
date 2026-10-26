import 'package:uuid/uuid.dart';

import 'inventory_quantity.dart';
import 'remote_json.dart';

class RemoteInvoiceSummary {
  final String id, rootId, number, type, status, deliveryStatus, paymentStatus;
  final String partyId, partyType, partyName;
  final String? phone, operationId;
  final DateTime createdAt;
  final DateTime? dueAt;
  final int total, openAmount, revision;
  final bool paymentApplicable;
  RemoteInvoiceSummary.fromJson(Object? value) : this._(RemoteJson(value));
  RemoteInvoiceSummary._(RemoteJson json)
    : id = json.text('invoiceId'),
      rootId = json.text('rootInvoiceId'),
      number = json.text('number'),
      type = json.text('type'),
      status = json.text('status'),
      deliveryStatus = json.text('deliveryStatus'),
      paymentStatus = json.text('paymentStatus'),
      partyId = RemoteJson(json.value['party']).text('partyId'),
      partyType = RemoteJson(json.value['party']).text('partyType'),
      partyName = RemoteJson(json.value['party']).text('name'),
      phone = RemoteJson(json.value['party']).optionalText('phone'),
      createdAt = DateTime.parse(json.text('createdAt')),
      dueAt = json.value['dueAt'] == null
          ? null
          : DateTime.parse(json.text('dueAt')),
      operationId = json.optionalText('operationId'),
      total = json.number('total'),
      openAmount = json.number('openAmount'),
      revision = json.number('revision'),
      paymentApplicable = json.flag('paymentApplicable') {
    if ([
          id,
          rootId,
          partyId,
          ?operationId,
        ].any((v) => !Uuid.isValidUUID(fromString: v)) ||
        ![
          'SALE',
          'PURCHASE',
          'PROFORMA',
          'PRESALE',
          'SALE_RETURN',
          'PURCHASE_RETURN',
        ].contains(type) ||
        ![
          'DRAFT',
          'ISSUED',
          'CANCELLED',
          'EXPIRED',
          'CONVERTED',
        ].contains(status) ||
        ![
          'PENDING',
          'READY',
          'SHIPPED',
          'DELIVERED',
        ].contains(deliveryStatus) ||
        !['UNPAID', 'PARTIALLY_PAID', 'PAID'].contains(paymentStatus) ||
        partyType != (type.startsWith('PURCHASE') ? 'SUPPLIER' : 'CUSTOMER') ||
        revision < 1) {
      throw const FormatException('Invalid invoice summary');
    }
    money(total);
    money(openAmount);
  }
  static int compareNumberDescending(
    RemoteInvoiceSummary a,
    RemoteInvoiceSummary b,
  ) {
    final first = BigInt.tryParse(a.number), second = BigInt.tryParse(b.number);
    final result = first != null && second != null
        ? second.compareTo(first)
        : b.number.compareTo(a.number);
    return result != 0 ? result : a.id.compareTo(b.id);
  }

  static int money(Object? value) {
    if (value is! int || value < 0 || value > 9007199254740991) {
      throw const FormatException('Invalid invoice money');
    }
    return value;
  }
}

class RemoteInvoiceLine {
  final String id, variantId, name;
  final String? sku;
  final InventoryQuantity quantity;
  final int unitPrice, amount;
  RemoteInvoiceLine.fromJson(Object? value) : this._(RemoteJson(value));
  RemoteInvoiceLine._(RemoteJson json)
    : id = json.text('lineId'),
      variantId = json.text('variantId'),
      name = json.text('name'),
      sku = json.optionalText('sku'),
      quantity = InventoryQuantity.fromJson(json.value['quantity']),
      unitPrice = RemoteInvoiceSummary.money(json.value['unitPrice']),
      amount = RemoteInvoiceSummary.money(json.value['amount']) {
    if (![id, variantId].every((v) => Uuid.isValidUUID(fromString: v))) {
      throw const FormatException('Invalid invoice line');
    }
  }
}

class RemoteInvoiceRelatedDocument {
  final String id, type, number, status;
  final int amount;
  final DateTime createdAt;
  final bool financialOnly;
  RemoteInvoiceRelatedDocument.fromJson(Object? value)
    : this._(RemoteJson(value));
  RemoteInvoiceRelatedDocument._(RemoteJson json)
    : id = json.text('invoiceId'),
      type = json.text('type'),
      number = json.text('number'),
      status = json.text('status'),
      amount = RemoteInvoiceSummary.money(json.value['amount']),
      createdAt = DateTime.parse(json.text('createdAt')),
      financialOnly = json.flag('financialOnly') {
    if (!Uuid.isValidUUID(fromString: id) ||
        ![
          'SALE',
          'PURCHASE',
          'PROFORMA',
          'PRESALE',
          'SALE_RETURN',
          'PURCHASE_RETURN',
        ].contains(type) ||
        ![
          'DRAFT',
          'ISSUED',
          'CANCELLED',
          'EXPIRED',
          'CONVERTED',
        ].contains(status)) {
      throw const FormatException('Invalid related invoice document');
    }
  }
}

class RemoteInvoiceDetail {
  final RemoteInvoiceSummary summary;
  final int businessId, settledAmount;
  final String branchId;
  final String? note, returnStatus;
  final List<RemoteInvoiceRelatedDocument>? relatedDocuments;
  final DateTime? validUntil;
  final String? convertedInvoiceId, referenceInvoiceId;
  final List<RemoteInvoiceLine> lines;
  final Map<String, int> totals;
  RemoteInvoiceDetail.fromJson(
    Object? value, {
    List<RemoteInvoiceRelatedDocument>? relatedDocuments,
  }) : this._(RemoteJson(value), relatedDocuments);
  RemoteInvoiceDetail._(RemoteJson json, this.relatedDocuments)
    : returnStatus = RemoteJson(json.value['view'])
          .optionalText('returnStatus'),
      summary = RemoteInvoiceSummary.fromJson({
        ...json.value,
        // The current view includes amendments/returns; root totals are historical.
        ...RemoteJson(json.value['view']).value,
        'party': json.value['partySnapshot'],
        'total': RemoteJson(RemoteJson(json.value['view']).value['totals'])
            .number('total'),
      }),
      businessId = json.number('businessId'),
      branchId = json.text('branchId'),
      note = json.optionalText('note'),
      validUntil = json.value['validUntil'] == null
          ? null
          : DateTime.parse(json.text('validUntil')),
      convertedInvoiceId = json.optionalText('convertedInvoiceId'),
      referenceInvoiceId = json.optionalText('referenceInvoiceId'),
      settledAmount = RemoteInvoiceSummary.money(
        RemoteJson(json.value['view']).value['settledAmount'],
      ),
      lines = RemoteJson(json.value['view'])
          .items('lines', RemoteInvoiceLine.fromJson),
      totals = Map.unmodifiable({
        for (final key in [
          'subtotal',
          'lineDiscount',
          'discountAmount',
          'shippingAmount',
          'surchargeAmount',
          'taxAmount',
          'total',
        ])
          key: RemoteInvoiceSummary.money(
            RemoteJson(RemoteJson(json.value['view']).value['totals'])
                .value[key],
          ),
      }) {
    if (returnStatus != null &&
            !['NONE', 'PARTIAL', 'FULL'].contains(returnStatus) ||
        !Uuid.isValidUUID(fromString: branchId) ||
        [
          ?convertedInvoiceId,
          ?referenceInvoiceId,
        ].any((id) => !Uuid.isValidUUID(fromString: id)) ||
        lines.length > 30 ||
        lines.map((l) => l.id).toSet().length != lines.length ||
        RemoteJson(RemoteJson(json.value['view']).value['totals'])
                .text('currency') !=
            'TOMAN') {
      throw const FormatException('Invalid invoice detail');
    }
  }
}
