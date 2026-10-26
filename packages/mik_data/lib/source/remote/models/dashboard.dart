import 'financial_report.dart';
import 'remote_json.dart';

class DashboardProfit {
  final Map<String, dynamic> json;
  final int businessId, sequence, inventorySequence;
  final String branchId;
  final DateTime startAt, endAt;
  final bool complete;
  final int? profit;
  DashboardProfit(Object? value) : this._(RemoteJson(value));
  DashboardProfit._(RemoteJson row)
    : json = Map.unmodifiable(row.value),
      businessId = row.number('businessId'),
      sequence = RemoteJson(row.value['snapshot']).number('sequence'),
      inventorySequence = RemoteJson(row.value['coverage'])
          .number('inventorySequence'),
      branchId = row.strings('branchIds').single,
      startAt = FinancialReportPage.date(row.text('startAt')),
      endAt = FinancialReportPage.date(row.text('endAt')),
      complete = row.flag('complete'),
      profit = row.value['netProfitBeforeIncomeTax'] == null
          ? null
          : FinancialReportPage.money(row.value['netProfitBeforeIncomeTax']) {
    FinancialReportPage.uuid(branchId);
    FinancialReportPage.date(RemoteJson(row.value['snapshot']).text('asOf'));
    if (row.text('scope') != 'BRANCH' ||
        row.text('currency') != 'TOMAN' ||
        row.text('basis') != 'PHYSICAL_DISPATCH_AND_POSTED_EXPENSES' ||
        sequence < 0 ||
        inventorySequence < 0 ||
        !endAt.isAfter(startAt) ||
        complete != (profit != null)) {
      throw const FormatException('Invalid dashboard profit');
    }
    final coverage = RemoteJson(row.value['coverage']);
    for (final key in [
      'unknownCosts',
      'missingCostPostings',
      'pending',
      'failed',
    ]) {
      if (coverage.number(key) < 0) {
        throw const FormatException('Invalid profit coverage');
      }
    }
    if (complete &&
        (coverage.number('unknownCosts') != 0 ||
            coverage.number('missingCostPostings') != 0 ||
            coverage.number('pending') != 0 ||
            coverage.flag('inventoryChanged'))) {
      throw const FormatException('Inconsistent profit coverage');
    }
  }
}

class DashboardProfitPoint {
  final String label;
  final int? current, previous;
  const DashboardProfitPoint(this.label, this.current, this.previous);
}
