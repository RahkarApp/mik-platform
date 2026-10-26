import 'financial_report.dart';
import 'remote_json.dart';

const partnerMovementKinds = {
  'CAPITAL_IN': 'آورده سرمایه',
  'CAPITAL_OUT': 'برداشت سرمایه',
  'CURRENT_IN': 'واریز حساب جاری',
  'CURRENT_OUT': 'برداشت حساب جاری',
  'NONCASH_CAPITAL_IN': 'آورده غیرنقدی',
  'REVERSAL': 'برگشت تراکنش',
};

class PartnerMovement {
  final Map<String, dynamic> json;
  PartnerMovement(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value) {
    final row = RemoteJson(json);
    for (final field in [
      'partnerMovementId',
      'partnerId',
      'branchId',
      'journalId',
    ]) {
      FinancialReportPage.uuid(row.text(field));
    }
    row.number('businessId');
    if (row.number('revision') < 1 ||
        !partnerMovementKinds.containsKey(row.text('kind')) ||
        FinancialReportPage.money(row.value['amount'], nonnegative: true) <=
            0) {
      throw const FormatException('Invalid partner movement');
    }
    for (final field in ['capitalDelta', 'currentDelta', 'currentBalance']) {
      FinancialReportPage.money(row.value[field]);
    }
    FinancialReportPage.money(row.value['capitalBalance'], nonnegative: true);
    FinancialReportPage.date(row.text('occurredAt'));
    row.text('reason');
    RemoteJson(row.value['partnerSnapshot']).text('name');
    if (kind == 'REVERSAL') {
      FinancialReportPage.uuid(row.text('originalMovementId'));
    }
    if (kind != 'REVERSAL') {
      final incoming = [
        'CAPITAL_IN',
        'CURRENT_IN',
        'NONCASH_CAPITAL_IN',
      ].contains(kind);
      final delta = incoming ? money('amount') : -money('amount');
      if (money('capitalDelta') != (kind.contains('CAPITAL') ? delta : 0) ||
          money('currentDelta') != (kind.startsWith('CURRENT') ? delta : 0) ||
          (kind == 'NONCASH_CAPITAL_IN'
              ? json['routing'] != null || json['method'] != null
              : json['routing'] == null)) {
        throw const FormatException('Invalid partner movement deltas');
      }
    }
    if (json['routing'] != null) {
      final route = RemoteJson(json['routing']);
      FinancialReportPage.uuid(route.text('fundId'));
      route.text('fundName');
      if (!['CASH', 'BANK_TRANSFER'].contains(row.text('method')) ||
          !(row.text('method') == 'CASH' ? ['CASH', 'PETTY_CASH'] : ['BANK'])
              .contains(route.text('kind'))) {
        throw const FormatException('Invalid partner fund');
      }
    } else {
      row.text('assetDescription');
    }
  }
  String get id => json['partnerMovementId'] as String;
  String get partnerId => json['partnerId'] as String;
  String get kind => json['kind'] as String;
  int money(String field) => FinancialReportPage.money(json[field]);
}
