import '../../source/remote/auth_error.dart';
import '../../source/remote/models/financial_report.dart';
import 'business_context.dart';
import 'sale_invoice.dart';
import 'treasury.dart';

class FinancialReportsFX {
  final BusinessContext context;
  final String branchId;
  late final access = TreasuryFX.forContext(context, branchId);
  FinancialReportsFX(this.context)
    : branchId = context.selectedBranch?.branchId ?? '';
  void check() {
    context.check();
    if (branchId.isEmpty || context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<void> authorize() async {
    check();
    await access.authorize();
    check();
  }

  bool has(String kind, {bool business = false}) =>
      access.has('accounting.report.$kind', business: business);

  Future<FinancialReportPage> page(
    String kind, {
    required bool business,
    DateTime? startAt,
    DateTime? endAt,
    String section = 'OBLIGATIONS',
    String groupBy = 'CATEGORY',
    String? fundId,
    String? cursor,
  }) async {
    if (startAt != null) {
      startAt = DateTime.fromMillisecondsSinceEpoch(
        startAt.millisecondsSinceEpoch,
        isUtc: true,
      );
    }
    if (endAt != null) {
      endAt = DateTime.fromMillisecondsSinceEpoch(
        endAt.millisecondsSinceEpoch,
        isUtc: true,
      );
    }
    check();
    if (!financialReportNames.containsKey(kind)) {
      throw const FormatException('Invalid report kind');
    }
    if (!has(kind, business: business)) throw const AuthError(403, 'FORBIDDEN');
    if (kind != 'balances' &&
        (startAt == null ||
            endAt == null ||
            !endAt.isAfter(startAt) ||
            endAt.difference(startAt) > const Duration(days: 400))) {
      throw const AuthError(400, 'REPORT_RANGE_INVALID');
    }
    if (kind == 'treasury') FinancialReportPage.uuid(fundId ?? '');
    final scope = business ? 'BUSINESS' : 'BRANCH';
    final result = FinancialReportPage(
      kind,
      await context.auth.request(
        'GET',
        '/v1/businesses/${context.session.business.businessId}/accounting/reports/$kind',
        branchId: branchId,
        query: {
          'scope': scope,
          'limit': '50',
          'cursor': ?cursor,
          if (kind != 'balances') ...{
            'startAt': startAt!.toUtc().toIso8601String(),
            'endAt': endAt!.toUtc().toIso8601String(),
          },
          if (kind == 'dues') 'section': section,
          if (kind == 'expenses') 'groupBy': groupBy,
          if (kind == 'treasury') 'fundId': fundId!,
        },
      ),
    );
    check();
    if (result.businessId != context.session.business.businessId ||
        result.scope != scope ||
        (business
            ? result.branchIds != null
            : result.branchIds?.length != 1 ||
                  result.branchIds!.single != branchId)) {
      throw const FormatException('Unexpected report scope');
    }
    for (final row in result.items) {
      // Fund journals may originate in another branch during a transfer;
      // only obligations must belong to the selected branch.
      if (!business &&
          ['balances', 'dues'].contains(kind) &&
          row['branchId'] != branchId) {
        throw const FormatException('Unexpected report row scope');
      }
    }
    if (kind == 'treasury' &&
            (result.json['fund'] as Map)['fundId'] != fundId ||
        kind == 'dues' && result.json['section'] != section ||
        kind == 'expenses' && result.json['groupBy'] != groupBy ||
        kind != 'balances' &&
            (FinancialReportPage.date(result.json['startAt'] as String) !=
                    startAt!.toUtc() ||
                FinancialReportPage.date(result.json['endAt'] as String) !=
                    endAt!.toUtc())) {
      throw const FormatException('Unexpected report filters');
    }
    if (kind == 'treasury') {
      final fund = result.json['fund'] as Map;
      if (fund['kind'] == 'BANK'
          ? !business || fund['branchId'] != null
          : fund['branchId'] != branchId) {
        throw const FormatException('Unexpected fund report scope');
      }
    }
    return result;
  }

  static String message(Object failure) {
    if (failure is FormatException) {
      return 'پاسخ گزارش کامل یا معتبر نیست؛ گزارش را دوباره دریافت کنید.';
    }
    if (failure is AuthError) {
      if (failure.code == 'VALIDATION_FAILED') {
        return 'سرور پارامترهای گزارش را نپذیرفت؛ بازهٔ تاریخ، محدودهٔ گزارش و صندوق انتخاب‌شده را بررسی کنید.';
      }
      if (failure.code == 'FORBIDDEN') {
        return 'مجوز مشاهده این گزارش یا سند را ندارید.';
      }
      if (failure.code == 'REPORT_SNAPSHOT_CHANGED') {
        return 'داده‌های مالی تغییر کرده یا مهلت گزارش تمام شده است؛ گزارش را از ابتدا دریافت کنید.';
      }
      if (failure.code == 'REPORT_RANGE_INVALID') {
        return 'بازه باید مثبت و حداکثر ۴۰۰ روز باشد.';
      }
      if (failure.code == 'MONEY_OVERFLOW') {
        return 'مبلغ گزارش از محدوده پشتیبانی‌شده بیشتر است.';
      }
      if (!failure.requiresLogin && failure.statusCode != 429) {
        final message = switch (failure.code) {
          'RECORD_NOT_FOUND' =>
            'صندوق، حساب یا سند انتخاب‌شده در سرور پیدا نشد.',
          'RPC_TIMEOUT' => 'مهلت پاسخ سرویس گزارش در سرور تمام شد.',
          'RPC_DEPENDENCY_FAILED' =>
            'یکی از سرویس‌های موردنیاز گزارش در دسترس نیست.',
          'INTERNAL_ERROR' => 'پردازش گزارش در سرور با خطای داخلی مواجه شد.',
          'INVALID_RESPONSE' =>
            'سرور یا واسط شبکه پاسخ معتبر گزارش را برنگرداند.',
          _ => 'دریافت گزارش انجام نشد.',
        };
        // A received HTTP error is different from a failed network connection.
        return '$message\nکد: ${failure.code} — HTTP ${failure.statusCode}'
            '${failure.requestId == null ? '' : '\nشناسه پیگیری: ${failure.requestId}'}';
      }
    }
    return SaleInvoiceFX.message(failure);
  }
}
