import 'package:uuid/uuid.dart';

import 'remote_json.dart';

const financialReportNames = {
  'balances': 'مانده تعهدات',
  'dues': 'سررسیدها',
  'expenses': 'گزارش هزینه‌ها',
  'cash-flow': 'گردش وجه',
  'treasury': 'گردش صندوق و بانک',
};

const financialAmountNames = {
  'receivableAmount': 'مطالبات',
  'payableAmount': 'بدهی‌ها',
  'overdueReceivableAmount': 'مطالبات سررسیدگذشته',
  'overduePayableAmount': 'بدهی‌های سررسیدگذشته',
  'bookedAmount': 'هزینه ثبت‌شده در دوره',
  'estimatedBookedAmount': 'بخش برآوردی هزینه ثبت‌شده',
  'currentlyRecordedAmount': 'مبلغ فعلی اسناد هزینه دوره',
  'currentlyPaidAmount': 'پرداخت قطعی فعلی این اسناد',
  'currentlyEstimatedPaidAmount': 'پرداخت برآوردی فعلی این اسناد',
  'pendingPaymentAmount': 'پرداخت در انتظار',
  'currentOutstandingAmount': 'مانده فعلی اسناد',
  'openingBalance': 'مانده ابتدای دوره',
  'closingBalance': 'مانده پایان دوره',
  'inflow': 'ورودی',
  'outflow': 'خروجی',
  'net': 'خالص گردش',
  'balance': 'مانده فعلی',
  'heldAmount': 'مبلغ مسدود فعلی',
  'availableAmount': 'قابل استفاده فعلی',
  'unreconciledAmount': 'مغایرت تطبیق‌نشده فعلی',
};

// Report totals come from the entire server snapshot, never from a visible page.
class FinancialReportPage {
  final String kind, scope, currency;
  final int businessId, sequence;
  final String asOf;
  final String? next;
  final List<String>? branchIds;
  final Map<String, dynamic> json;
  final List<Map<String, dynamic>> items;
  FinancialReportPage(String kind, Object? value)
    : this._(kind, RemoteJson(value));
  FinancialReportPage._(this.kind, RemoteJson row)
    : scope = row.text('scope'),
      currency = row.text('currency'),
      businessId = row.number('businessId'),
      sequence = RemoteJson(row.value['snapshot']).number('sequence'),
      asOf = RemoteJson(row.value['snapshot']).text('asOf'),
      next = row.optionalText('nextCursor'),
      branchIds = row.value['branchIds'] == null
          ? null
          : row.strings('branchIds'),
      json = Map.unmodifiable(row.value),
      items = row.items('items', (r) => Map.unmodifiable(RemoteJson(r).value)) {
    if (!financialReportNames.containsKey(kind) ||
        !['BUSINESS', 'BRANCH'].contains(scope) ||
        currency != 'TOMAN' ||
        sequence < 0 ||
        next != null && !RegExp(r'^[A-Za-z0-9_-]{1,800}$').hasMatch(next!)) {
      throw const FormatException('Invalid financial report');
    }
    date(asOf);
    if (branchIds != null) {
      for (final id in branchIds!) {
        uuid(id);
      }
    }
    if (kind != 'balances') {
      date(row.text('startAt'));
      date(row.text('endAt'));
    }
    if (['balances', 'dues'].contains(kind)) {
      final totals = RemoteJson(json['totals']);
      if (totals.number('count') < 0) {
        throw const FormatException('Invalid count');
      }
      for (final key in financialAmountNames.keys.take(4)) {
        money(totals.value[key], nonnegative: true);
      }
      if (kind == 'balances') {
        if (row.text('basis') != 'CURRENT_OPEN_OBLIGATIONS') {
          throw const FormatException('Unexpected balance basis');
        }
        final credit = json['creditBalances'];
        if (credit != null) {
          final c = RemoteJson(credit);
          if (c.flag('additiveToOpenItems')) {
            throw const FormatException('Invalid credits');
          }
          for (final r in c.items('partyAccounts', RemoteJson.new)) {
            r.text('partyType');
            money(r.value['debt']);
            money(r.value['credit']);
          }
          for (final group in ['unallocatedCredit', 'classifiedAdvances']) {
            for (final r in c.items(group, RemoteJson.new)) {
              r.text('partyType');
              money(r.value['amount']);
            }
          }
          for (final r in c.items('clearing', RemoteJson.new)) {
            r.text('kind');
            money(r.value['amount']);
          }
        }
      } else {
        if (!['OBLIGATIONS', 'CHEQUES'].contains(row.text('section')) ||
            row.flag('additiveToOtherSections')) {
          throw const FormatException('Invalid dues section');
        }
      }
    }
    if (kind == 'expenses') {
      if (!['CATEGORY', 'BRANCH'].contains(row.text('groupBy')) ||
          row.flag('settlementIsCashflowInRange')) {
        throw const FormatException('Invalid expense report');
      }
      for (final key in expenseFields) {
        money(RemoteJson(json['totals']).value[key]);
      }
    }
    if (kind == 'cash-flow') {
      row.flag('sharedBankExcluded');
      row.flag('unclassified');
      for (final section in ['totals', 'externalCashflow']) {
        for (final key in ['inflow', 'outflow', 'net']) {
          money(RemoteJson(json[section]).value[key]);
        }
      }
    }
    if (['treasury', 'cash-flow'].contains(kind)) {
      money(json['openingBalance']);
      money(json['closingBalance']);
    }
    if (kind == 'treasury') {
      final fund = RemoteJson(json['fund']);
      uuid(fund.text('fundId'));
      fund.text('name');
      if (!['BANK', 'CASH', 'PETTY_CASH'].contains(fund.text('kind'))) {
        throw const FormatException('Invalid report fund');
      }
      money(json['inflow']);
      money(json['outflow']);
      for (final key in [
        'balance',
        'heldAmount',
        'availableAmount',
        'unreconciledAmount',
      ]) {
        money(RemoteJson(json['current']).value[key]);
      }
    }
    final keys = <String>{};
    for (final item in items) {
      final r = RemoteJson(item);
      if (!keys.add(itemKey(item))) {
        throw const FormatException('Repeated report row');
      }
      if (['balances', 'dues'].contains(kind)) {
        if (!['IN', 'OUT'].contains(r.text('direction'))) {
          throw const FormatException('Invalid direction');
        }
        uuid(r.text('recordId'));
        r.text('source');
        money(item['amount'], nonnegative: true);
        if (item['pendingAmount'] != null) {
          money(item['pendingAmount'], nonnegative: true);
        }
        money(item['overdueAmount'], nonnegative: true);
        if (item['dueAt'] != null) date(r.text('dueAt'));
      } else if (kind == 'expenses') {
        r.text('name');
        for (final key in expenseFields) {
          money(item[key]);
        }
      } else {
        money(item['inflow'], nonnegative: true);
        money(item['outflow'], nonnegative: true);
        if (kind == 'cash-flow') {
          r.text('category');
          money(item['net']);
        }
        if (kind == 'treasury') {
          uuid(r.text('journalId'));
          uuid(r.text('sourceId'));
          r.text('sourceType');
          date(r.text('occurredAt'));
          if (r.number('sequence') < 1) {
            throw const FormatException('Invalid journal sequence');
          }
        }
      }
    }
  }
  static const expenseFields = [
    'bookedAmount',
    'estimatedBookedAmount',
    'currentlyRecordedAmount',
    'currentlyPaidAmount',
    'currentlyEstimatedPaidAmount',
    'pendingPaymentAmount',
    'currentOutstandingAmount',
  ];
  String itemKey(Map<String, dynamic> item) => kind == 'treasury'
      ? RemoteJson(item).text('journalId')
      : RemoteJson(item).text('key');
  static int money(Object? value, {bool nonnegative = false}) {
    if (value is! int ||
        value.abs() > 9007199254740991 ||
        nonnegative && value < 0) {
      throw const FormatException('Invalid report amount');
    }
    return value;
  }

  static DateTime date(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) throw const FormatException('Invalid report date');
    return date;
  }

  static void uuid(String value) {
    if (!Uuid.isValidUUID(fromString: value)) {
      throw const FormatException('Invalid report ID');
    }
  }
}
