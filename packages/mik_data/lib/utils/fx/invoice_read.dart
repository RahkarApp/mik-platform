import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/invoice_read.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';
import 'sale_invoice.dart';

class InvoiceReadFX {
  final BusinessContext context;
  final String branchId;
  final SaleInvoiceFX access;
  InvoiceReadFX(this.context)
    : branchId = context.selectedBranch?.branchId ?? '',
      access = SaleInvoiceFX(context: context);
  int get businessId => context.session.business.businessId;
  String get branchName => context.selectedBranch?.name ?? branchId;
  void check() => access.check();
  Future<void> authorize(String type) async {
    await access.authorize();
    access.require(permission(type));
  }

  static String permission(String type) => switch (type) {
    'SALE' => 'accounting.sale.read',
    'PURCHASE' => 'accounting.purchase.read',
    'PROFORMA' => 'accounting.proforma.read',
    'SALE_RETURN' => 'accounting.sale-return.read',
    'PURCHASE_RETURN' => 'accounting.purchase-return.read',
    'PRESALE' => 'accounting.presale.read',
    _ => throw const FormatException('Unsupported invoice tab'),
  };
  Future<({List<RemoteInvoiceSummary> items, String? next})> page(
    String type, {
    String? after,
    String? status,
  }) async {
    access.require(permission(type));
    final json = RemoteJson(
      await context.request(
        'GET',
        '/v1/businesses/$businessId/accounting/v2/invoices',
        query: {
          'types': type,
          'limit': '30',
          'after': ?after,
          'status': ?status,
        },
      ),
    );
    check();
    final rows = json.items('items', RemoteInvoiceSummary.fromJson);
    if (json.number('businessId') != businessId ||
        rows.any(
          (r) =>
              r.type != type ||
              r.id != r.rootId ||
              status != null && r.status != status,
        )) {
      throw const FormatException('Unexpected invoice page');
    }
    return (items: rows, next: json.optionalText('nextCursor'));
  }

  Future<RemoteInvoiceDetail> detail(String id, String type) async {
    await authorize(type);
    final json = RemoteJson(
      await context.request(
        'GET',
        '/v1/businesses/$businessId/accounting/v2/invoices/${Uri.encodeComponent(id)}',
      ),
    );
    check();
    final result = RemoteInvoiceDetail.fromJson(
      json.value['invoice'],
      relatedDocuments: json.items(
        'relatedDocuments',
        RemoteInvoiceRelatedDocument.fromJson,
      ),
    );
    if (json.number('businessId') != businessId ||
        result.businessId != businessId ||
        result.branchId != branchId ||
        result.summary.id != id ||
        result.summary.type != type) {
      throw const FormatException('Unexpected invoice detail scope');
    }
    return result;
  }

  static String message(Object failure) {
    if (failure is FormatException) {
      return 'پاسخ فاکتور کامل یا معتبر نیست؛ دوباره تلاش کنید.';
    }
    if (failure is AuthError) {
      if (failure.code == 'FORBIDDEN') {
        return 'مجوز مشاهده این فاکتورها را ندارید.';
      }
      if (failure.code == 'SELECTION_CHANGED') {
        return 'نشست یا شعبه تغییر کرده است؛ صفحه را دوباره باز کنید.';
      }
      if (failure.code == 'RECORD_NOT_FOUND') {
        return 'فاکتور در کسب‌وکار انتخاب‌شده پیدا نشد.';
      }
      if (!failure.requiresLogin && failure.statusCode < 500) {
        return 'دریافت فاکتور انجام نشد؛ کد خطای سرور: ${failure.code}';
      }
    }
    return API.loginError(failure);
  }
}
