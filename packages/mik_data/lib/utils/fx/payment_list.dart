import '../../source/remote/auth_error.dart';
import '../../source/remote/models/financial_report.dart';
import '../../source/remote/models/invoice_payment.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';
import 'treasury.dart';

class ListedPayment {
  final InvoicePartyPayment payment;
  final String createdAt;
  ListedPayment(Object? value)
    : payment = InvoicePartyPayment.fromJson(value),
      createdAt = RemoteJson(value).text('createdAt') {
    FinancialReportPage.date(createdAt);
  }
}

class PaymentListFX {
  final BusinessContext context;
  final String branchId;
  late final access = TreasuryFX.forContext(context, branchId);
  PaymentListFX(this.context)
    : branchId = context.selectedBranch?.branchId ?? '';
  void check() {
    context.check();
    if (branchId.isEmpty || context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  bool get canReadAccount =>
      access.has('accounting.account.read', business: true);
  Future<InvoicePaymentDetail> detail(String id) async {
    check();
    FinancialReportPage.uuid(id);
    await access.authorize();
    if (!access.has('accounting.payment.read', business: true)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final row = RemoteJson(
      await context.auth.request(
        'GET',
        '/v1/businesses/${access.businessId}/accounting/v2/payments/$id',
        branchId: branchId,
      ),
    );
    check();
    final result = InvoicePaymentDetail.fromJson(row.value['item']);
    if (row.number('businessId') != access.businessId ||
        result.payment.businessId != access.businessId ||
        result.payment.id != id) {
      throw const FormatException('Unexpected payment detail');
    }
    return result;
  }

  Future<List<ListedPayment>> load({bool Function()? isActive}) async {
    check();
    await access.authorize();
    if (!access.has('accounting.payment.read', business: true)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final rows = <ListedPayment>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      check();
      if (isActive != null && !isActive()) {
        throw const AuthError(409, 'SELECTION_CHANGED');
      }
      final data = RemoteJson(
        await context.auth.request(
          'GET',
          '/v1/businesses/${access.businessId}/accounting/v2/payments',
          branchId: branchId,
          query: {'limit': '100', 'after': ?after},
        ),
      );
      check();
      if (data.number('businessId') != access.businessId) {
        throw const FormatException('Unexpected payment business');
      }
      final page = data.items('items', ListedPayment.new);
      for (final row in page) {
        final payment = row.payment;
        if (payment.businessId != access.businessId ||
            !ids.add(payment.id) ||
            after != null && payment.id.compareTo(after) <= 0) {
          throw const FormatException('Unexpected or repeated payment');
        }
        rows.add(row);
      }
      final next = data.optionalText('nextCursor');
      if (next != null) {
        FinancialReportPage.uuid(next);
        if (page.isEmpty ||
            next != page.last.payment.id ||
            !cursors.add(next)) {
          throw const FormatException('Invalid payment cursor');
        }
      }
      after = next;
    } while (after != null);
    // The server has no direction filter. Read all pages before splitting tabs.
    rows.sort(
      (a, b) =>
          DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)),
    );
    return List.unmodifiable(rows);
  }
}
