import 'financial_report.dart';
import 'remote_json.dart';

const loanStatuses = {
  'DRAFT': 'پیش‌نویس',
  'ACTIVE': 'فعال',
  'SETTLED': 'تسویه‌شده',
  'CANCELLED': 'لغوشده',
};
const loanDirections = {'RECEIVED': 'وام دریافتی', 'GRANTED': 'وام پرداختی'};

class RemoteLoan {
  final Map<String, dynamic> json;
  RemoteLoan(Object? value, {bool presented = true})
    : json = Map.unmodifiable(RemoteJson(value).value) {
    final row = RemoteJson(json);
    FinancialReportPage.uuid(row.text('loanId'));
    if (row.number('revision') < 1 ||
        !loanStatuses.containsKey(row.text('status')) ||
        !loanDirections.containsKey(row.text('direction'))) {
      throw const FormatException('Invalid loan');
    }
    row.number('businessId');
    row.text('name');
    final party = RemoteJson(row.value['counterparty']);
    party.text('name');
    party.optionalText('phone');
    party.optionalText('reference');
    if (row.value['partnerId'] != null) {
      FinancialReportPage.uuid(row.text('partnerId'));
    }
    for (final field in amounts.keys) {
      FinancialReportPage.money(json[field], nonnegative: true);
    }
    if (money('principalAmount') <= 0 ||
        money('paidPrincipalAmount') + money('pendingPrincipalAmount') >
            money('principalAmount') ||
        money('paidChargeAmount') +
                money('pendingChargeAmount') +
                money('waivedChargeAmount') >
            money('contractChargeAmount') ||
        money('accruedChargeAmount') < money('paidChargeAmount')) {
      throw const FormatException('Invalid loan balance');
    }
    if (json['fundedAt'] != null) {
      FinancialReportPage.date(row.text('fundedAt'));
    }
    if (['ACTIVE', 'SETTLED'].contains(status) && json['fundedAt'] == null) {
      throw const FormatException('Unfunded active loan');
    }
    if (json['fundedAt'] != null) {
      final funding = RemoteJson(json['funding']),
          route = RemoteJson(RemoteJson(json['funding']).value['routing']);
      FinancialReportPage.uuid(funding.text('branchId'));
      FinancialReportPage.uuid(route.text('fundId'));
      route.text('fundName');
      if (!['CASH', 'BANK_TRANSFER'].contains(funding.text('method')) ||
          !(funding.text('method') == 'CASH'
                  ? ['CASH', 'PETTY_CASH']
                  : ['BANK'])
              .contains(route.text('kind'))) {
        throw const FormatException('Invalid loan funding route');
      }
    }
    if (presented) {
      for (final field in summary.keys) {
        FinancialReportPage.money(json[field], nonnegative: true);
      }
      if (money('outstandingPrincipal') !=
              (json['fundedAt'] == null
                  ? 0
                  : money('principalAmount') - money('paidPrincipalAmount')) ||
          money('outstandingRecognizedCharges') !=
              money('accruedChargeAmount') - money('paidChargeAmount') ||
          money('remainingContractCharges') !=
              money('contractChargeAmount') -
                  money('waivedChargeAmount') -
                  money('paidChargeAmount')) {
        throw const FormatException('Invalid loan summary');
      }
    }
  }
  String get id => json['loanId'] as String;
  String get status => json['status'] as String;
  int get revision => json['revision'] as int;
  int money(String field) =>
      FinancialReportPage.money(json[field], nonnegative: true);
  static const amounts = {
    'principalAmount': 'اصل قرارداد',
    'contractChargeAmount': 'هزینه/درآمد مالی قرارداد',
    'paidPrincipalAmount': 'اصل بازپرداخت‌شده',
    'paidChargeAmount': 'هزینه/درآمد پرداخت‌شده',
    'accruedChargeAmount': 'هزینه/درآمد شناسایی‌شده',
    'waivedChargeAmount': 'بخشوده‌شده',
    'pendingPrincipalAmount': 'اصل در انتظار',
    'pendingChargeAmount': 'هزینه/درآمد در انتظار',
  };
  static const summary = {
    'outstandingPrincipal': 'مانده اصل',
    'outstandingRecognizedCharges': 'مانده شناسایی‌شده',
    'remainingContractCharges': 'مانده هزینه/درآمد قرارداد',
  };
}

class LoanInstallment {
  final Map<String, dynamic> json;
  LoanInstallment(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value) {
    final row = RemoteJson(json);
    FinancialReportPage.uuid(row.text('loanInstallmentId'));
    FinancialReportPage.uuid(row.text('loanId'));
    row.number('businessId');
    if (row.number('number') < 1 || row.number('revision') < 1) {
      throw const FormatException('Invalid installment');
    }
    FinancialReportPage.date(row.text('dueAt'));
    for (final field in [
      'principalAmount',
      'chargeAmount',
      'paidPrincipalAmount',
      'paidChargeAmount',
      'accruedChargeAmount',
      'waivedChargeAmount',
      'pendingPrincipalAmount',
      'pendingChargeAmount',
    ]) {
      money(field);
    }
    if (money('paidPrincipalAmount') + money('pendingPrincipalAmount') >
            money('principalAmount') ||
        money('paidChargeAmount') +
                money('pendingChargeAmount') +
                money('waivedChargeAmount') >
            money('chargeAmount')) {
      throw const FormatException('Invalid installment balances');
    }
    if (json['status'] != null &&
        !['PAID', 'OVERDUE', 'SCHEDULED'].contains(row.text('status'))) {
      throw const FormatException('Invalid installment status');
    }
    if (json.containsKey('outstandingPrincipal') &&
            money('outstandingPrincipal') !=
                money('principalAmount') - money('paidPrincipalAmount') ||
        json.containsKey('outstandingCharge') &&
            money('outstandingCharge') !=
                money('chargeAmount') -
                    money('waivedChargeAmount') -
                    money('paidChargeAmount')) {
      throw const FormatException('Invalid installment summary');
    }
  }
  String get id => json['loanInstallmentId'] as String;
  int money(String field) =>
      FinancialReportPage.money(json[field], nonnegative: true);
}

class LoanPayment {
  final Map<String, dynamic> json;
  LoanPayment(Object? value)
    : json = Map.unmodifiable(RemoteJson(value).value) {
    final row = RemoteJson(json);
    for (final field in ['loanPaymentId', 'loanId', 'branchId']) {
      FinancialReportPage.uuid(row.text(field));
    }
    row.number('businessId');
    if (row.number('revision') < 1 ||
        !['CASH', 'BANK_TRANSFER', 'CHEQUE'].contains(row.text('method')) ||
        ![
          'PENDING',
          'CONFIRMED',
          'BOUNCED',
          'RETURNED',
          'REVERSED',
        ].contains(row.text('status'))) {
      throw const FormatException('Invalid loan payment');
    }
    if (money('amount') <= 0 ||
        money('amount') != money('principalAmount') + money('chargeAmount')) {
      throw const FormatException('Invalid loan payment amount');
    }
    FinancialReportPage.date(row.text('occurredAt'));
    final route = RemoteJson(json['routing']);
    FinancialReportPage.uuid(route.text('fundId'));
    route.text('fundName');
    if (!(row.text('method') == 'CASH' ? ['CASH', 'PETTY_CASH'] : ['BANK'])
            .contains(route.text('kind')) ||
        row.text('method') != 'CHEQUE' &&
            ['PENDING', 'BOUNCED', 'RETURNED'].contains(row.text('status'))) {
      throw const FormatException('Invalid loan payment route/state');
    }
    if (row.text('method') == 'CHEQUE') {
      final cheque = RemoteJson(row.value['cheque']);
      cheque.text('bankName');
      cheque.text('number');
      FinancialReportPage.date(cheque.text('dueAt'));
      if (cheque.value['sayadId'] != null &&
          !RegExp(r'^\d{16}$').hasMatch(cheque.text('sayadId'))) {
        throw const FormatException('Invalid loan cheque identifier');
      }
      cheque.optionalText('drawerName');
    }
    final ids = <String>{};
    var principal = 0, charge = 0;
    for (final part in row.items('allocations', RemoteJson.new)) {
      final id = part.text('loanInstallmentId');
      FinancialReportPage.uuid(id);
      if (!ids.add(id)) throw const FormatException('Repeated loan allocation');
      final p = FinancialReportPage.money(
            part.value['principalAmount'],
            nonnegative: true,
          ),
          c = FinancialReportPage.money(
            part.value['chargeAmount'],
            nonnegative: true,
          );
      if (p + c <= 0) throw const FormatException('Empty loan allocation');
      principal += p;
      charge += c;
    }
    if (principal != money('principalAmount') ||
        charge != money('chargeAmount')) {
      throw const FormatException('Loan allocations mismatch');
    }
  }
  int money(String field) =>
      FinancialReportPage.money(json[field], nonnegative: true);
}
