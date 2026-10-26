import 'package:uuid/uuid.dart';

import 'invoice_read.dart';
import 'remote_json.dart';

class RemoteExpense {
  final Map<String, dynamic> json;
  RemoteExpense(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value) {
    final row = RemoteJson(json);
    for (final key in ['expenseId', 'branchId', 'categoryId', 'payeeId']) {
      if (!Uuid.isValidUUID(fromString: row.text(key))) {
        throw const FormatException('Invalid expense identity');
      }
    }
    if (revision < 1 ||
        !['ISSUED', 'VOIDED'].contains(status) ||
        ![
          'UNPAID',
          'PARTIALLY_PAID',
          'PAID',
        ].contains(row.text('paymentStatus'))) {
      throw const FormatException('Invalid expense state');
    }
    for (final key in ['amount', 'paidAmount', 'pendingAmount']) {
      money(key);
    }
    if (money('amount') <= 0 || remaining < 0) {
      throw const FormatException('Invalid expense amounts');
    }
    row.text('title');
    RemoteJson(json['categorySnapshot']).text('name');
    RemoteJson(json['payeeSnapshot']).text('name');
    DateTime.parse(row.text('occurredAt'));
    if (json['dueAt'] != null) DateTime.parse(row.text('dueAt'));
  }
  String get id => json['expenseId'] as String;
  int get revision => json['revision'] as int;
  String get status => json['status'] as String;
  int money(String key) => RemoteInvoiceSummary.money(json[key]);
  int get remaining =>
      money('amount') - money('paidAmount') - money('pendingAmount');
}

class ExpenseCategory {
  final Map<String, dynamic> json;
  ExpenseCategory(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value) {
    final row = RemoteJson(json);
    if (!Uuid.isValidUUID(fromString: id) ||
        row.number('revision') < 1 ||
        !['ACTIVE', 'ARCHIVED'].contains(status)) {
      throw const FormatException('Invalid expense category');
    }
    row.text('name');
  }
  String get id => json['categoryId'] as String;
  String get name => json['name'] as String;
  String get status => json['status'] as String;
}

class ExpenseDisbursement {
  final Map<String, dynamic> json;
  ExpenseDisbursement(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value) {
    final row = RemoteJson(json);
    for (final key in ['disbursementId', 'expenseId', 'payeeId', 'branchId']) {
      if (!Uuid.isValidUUID(fromString: row.text(key))) {
        throw const FormatException('Invalid expense payment');
      }
    }
    if (row.number('revision') < 1 ||
        RemoteInvoiceSummary.money(json['amount']) <= 0 ||
        ![
          'CASH',
          'CARD',
          'BANK_TRANSFER',
          'CHEQUE',
          'WITHHELD',
        ].contains(method) ||
        ![
          'PENDING',
          'CONFIRMED',
          'BOUNCED',
          'RETURNED',
          'REVERSED',
        ].contains(status)) {
      throw const FormatException('Invalid disbursement state');
    }
    if (!Uuid.isValidUUID(
      fromString: RemoteJson(json['routing']).text('fundId'),
    )) {
      throw const FormatException('Invalid disbursement fund');
    }
    if (method == 'CHEQUE') {
      final cheque = RemoteJson(json['cheque']);
      cheque.text('bankName');
      cheque.text('number');
      DateTime.parse(cheque.text('dueAt'));
    }
  }
  String get id => json['disbursementId'] as String;
  String get method => json['method'] as String;
  String get status => json['status'] as String;
}
