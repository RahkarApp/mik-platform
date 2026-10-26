import 'financial_report.dart';
import 'remote_json.dart';

class AssetCategory {
  final String id, name, status;
  final int businessId, revision;
  AssetCategory(Object? value) : this._(RemoteJson(value));
  AssetCategory._(RemoteJson row)
    : id = row.text('assetCategoryId'),
      name = row.text('name'),
      status = row.text('status'),
      businessId = row.number('businessId'),
      revision = row.number('revision') {
    FinancialReportPage.uuid(id);
    if (revision < 1 || !['ACTIVE', 'ARCHIVED'].contains(status)) {
      throw const FormatException('Invalid asset category');
    }
  }
}

const assetStatuses = {
  'REGISTERED': 'ثبت‌شده',
  'IN_USE': 'در حال استفاده',
  'UNDER_REPAIR': 'در حال تعمیر',
  'SOLD': 'فروخته‌شده',
  'SCRAPPED': 'اسقاط‌شده',
  'LOST': 'مفقودشده',
  'CANCELLED': 'لغوشده',
};
const assetPaymentStatuses = {
  'NOT_APPLICABLE': 'بدون تعهد پرداخت',
  'UNPAID': 'پرداخت‌نشده',
  'PARTIALLY_PAID': 'بخشی پرداخت‌شده',
  'PAID': 'تسویه‌شده',
};
const assetMovementNames = {
  'ACQUIRE': 'ثبت دارایی',
  'UPDATE': 'ویرایش مشخصات',
  'COMMISSION': 'شروع بهره‌برداری',
  'TRANSFER': 'انتقال شعبه',
  'CUSTODY': 'تغییر تحویل‌گیرنده',
  'DEPRECIATE': 'ثبت استهلاک',
  'REPAIR': 'تعمیر',
  'CAPITALIZE': 'افزایش بهای دارایی',
  'PAYMENT': 'پرداخت',
  'PAYMENT_STATUS': 'تغییر وضعیت پرداخت',
  'PAYMENT_REVERSE': 'برگشت پرداخت',
  'DISPOSE': 'خروج دارایی',
  'CANCEL': 'لغو ثبت',
};

class RemoteFixedAsset {
  int get uncoveredAmount =>
      money('acquisitionCost') - money('paidAmount') - money('pendingAmount');
  final Map<String, dynamic> json;
  final String id, branchId, name, code, status, category;
  final int businessId, revision;
  RemoteFixedAsset(Object? value) : this._(RemoteJson(value));
  RemoteFixedAsset._(RemoteJson row)
    : json = Map.unmodifiable(row.value),
      id = row.text('fixedAssetId'),
      branchId = row.text('branchId'),
      name = row.text('name'),
      code = row.text('code'),
      status = row.text('status'),
      businessId = row.number('businessId'),
      revision = row.number('revision'),
      category = RemoteJson(row.value['categorySnapshot']).text('name') {
    for (final field in ['fixedAssetId', 'branchId', 'assetCategoryId']) {
      FinancialReportPage.uuid(row.text(field));
    }
    if (revision < 1 ||
        !assetStatuses.containsKey(status) ||
        !assetPaymentStatuses.containsKey(row.text('paymentStatus')) ||
        !['PURCHASE', 'OPENING', 'CONTRIBUTION'].contains(row.text('source')) ||
        !['NONE', 'STRAIGHT_LINE'].contains(row.text('depreciationMethod'))) {
      throw const FormatException('Invalid fixed asset');
    }
    for (final key in amounts.keys) {
      FinancialReportPage.money(row.value[key], nonnegative: true);
    }
    for (final key in dates.keys) {
      if (row.value[key] != null) day(row.text(key));
    }
    for (final key in [
      'acquiredOn',
      'registeredOn',
      'depreciatedThrough',
      'financialThrough',
    ]) {
      day(row.text(key));
    }
    for (final key in ['serialNumber', 'location', 'note']) {
      row.optionalText(key);
    }
    if (row.value['supplierSnapshot'] != null) {
      RemoteJson(row.value['supplierSnapshot']).text('name');
    }
    if (row.value['custodian'] != null) {
      final custodian = RemoteJson(row.value['custodian']);
      custodian.text('displayName');
      FinancialReportPage.uuid(custodian.text('membershipId'));
    }
    if (row.value['usefulLifeMonths'] != null) {
      final months = row.number('usefulLifeMonths');
      if (months < 1 || months > 1200) {
        throw const FormatException('Invalid useful life');
      }
    }
  }
  static const amounts = {
    'acquisitionCost': 'بهای تحصیل',
    'cost': 'بهای ثبت‌شده',
    'accumulatedDepreciation': 'استهلاک انباشته',
    'bookValue': 'ارزش دفتری',
    'residualValue': 'ارزش اسقاط',
    'paidAmount': 'پرداخت قطعی',
    'pendingAmount': 'پرداخت در انتظار',
    'liabilityAmount': 'مانده تعهد',
  };
  static const dates = {
    'acquiredOn': 'تاریخ تحصیل',
    'registeredOn': 'تاریخ ثبت',
    'inServiceOn': 'شروع بهره‌برداری',
    'depreciatedThrough': 'استهلاک ثبت‌شده تا',
    'financialThrough': 'آخرین تاریخ مالی',
    'dueOn': 'سررسید',
    'warrantyUntil': 'پایان ضمانت',
  };
  int money(String key) =>
      FinancialReportPage.money(json[key], nonnegative: true);
  static void day(String value) {
    final parsed = DateTime.tryParse(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != value) {
      throw const FormatException('Invalid asset date');
    }
  }
}

class AssetPayment {
  final Map<String, dynamic> json;
  final String id, assetId, branchId, supplierId, method, status, fundId;
  final int businessId, revision, amount;
  AssetPayment(Object? value) : this._(RemoteJson(value));
  AssetPayment._(RemoteJson row)
    : json = Map.unmodifiable(row.value),
      id = row.text('assetPaymentId'),
      assetId = row.text('fixedAssetId'),
      branchId = row.text('branchId'),
      supplierId = row.text('supplierId'),
      method = row.text('method'),
      status = row.text('status'),
      businessId = row.number('businessId'),
      revision = row.number('revision'),
      amount = FinancialReportPage.money(
        row.value['amount'],
        nonnegative: true,
      ),
      fundId = RemoteJson(row.value['routing']).text('fundId') {
    for (final id in [id, assetId, branchId, supplierId, fundId]) {
      FinancialReportPage.uuid(id);
    }
    if (revision < 1 ||
        amount <= 0 ||
        !['CASH', 'BANK_TRANSFER', 'CHEQUE'].contains(method) ||
        ![
          'PENDING',
          'CONFIRMED',
          'BOUNCED',
          'RETURNED',
          'REVERSED',
        ].contains(status) ||
        method != 'CHEQUE' &&
            ['PENDING', 'BOUNCED', 'RETURNED'].contains(status)) {
      throw const FormatException('Invalid asset payment');
    }
    if (method == 'CHEQUE') {
      final cheque = RemoteJson(row.value['cheque']);
      cheque.text('bankName');
      cheque.text('number');
      FinancialReportPage.date(cheque.text('dueAt'));
      final sayad = cheque.optionalText('sayadId');
      if (sayad != null && !RegExp(r'^\d{16}$').hasMatch(sayad)) {
        throw const FormatException('Invalid sayad');
      }
      cheque.optionalText('drawerName');
    }
  }
}

class RemoteAssetMovement {
  final String id, assetId, branchId, kind, on, reason;
  final String? toBranchId;
  final int businessId, number;
  final bool financial;
  RemoteAssetMovement(Object? value) : this._(RemoteJson(value));
  RemoteAssetMovement._(RemoteJson row)
    : id = row.text('assetMovementId'),
      assetId = row.text('fixedAssetId'),
      branchId = row.text('branchId'),
      toBranchId = row.optionalText('toBranchId'),
      kind = row.text('kind'),
      on = row.text('effectiveOn'),
      reason = row.text('reason'),
      businessId = row.number('businessId'),
      number = row.number('number'),
      financial = row.flag('financial') {
    for (final value in [id, assetId, branchId, ?toBranchId]) {
      FinancialReportPage.uuid(value);
    }
    RemoteFixedAsset.day(on);
    if (!assetMovementNames.containsKey(kind) || number < 1) {
      throw const FormatException('Invalid asset movement');
    }
  }
}
