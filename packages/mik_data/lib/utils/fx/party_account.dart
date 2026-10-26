import '../../source/remote/auth_error.dart';
import '../../source/remote/models/financial_report.dart';
import '../../source/remote/models/remote_json.dart';
import '../../source/remote/models/invoice_payment.dart';
import '../../source/remote/models/invoice_read.dart';
import 'business_context.dart';
import 'treasury.dart';

class PartyAccountPage {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> items;
  final int? next;
  PartyAccountPage(
    Object? value,
    int businessId,
    String type,
    String id, {
    int after = 0,
  }) : this._(RemoteJson(value), businessId, type, id, after);
  PartyAccountPage._(
    RemoteJson row,
    int businessId,
    String type,
    String id,
    int after,
  ) : summary = Map.unmodifiable(row.value),
      items = row.items('items', (v) => Map.unmodifiable(RemoteJson(v).value)),
      next = row.optionalNumber('nextSequence') {
    final party = RemoteJson(row.value['party']);
    if (row.number('businessId') != businessId ||
        party.text('partyType') != type ||
        party.text('partyId') != id) {
      throw const FormatException('Unexpected account scope');
    }
    party.text('name');
    final account = row.optionalText('accountId');
    if (account != null) FinancialReportPage.uuid(account);
    final pending = row.optionalText('operationPending');
    if (pending != null) FinancialReportPage.uuid(pending);
    for (final key in [
      'balance',
      'debt',
      'credit',
      'availableCredit',
      'invoiceOutstanding',
      'overdueAmount',
      'pendingChequeAmount',
    ]) {
      FinancialReportPage.money(row.value[key], nonnegative: key != 'balance');
    }
    final balance = money('balance');
    if (money('debt') != (balance > 0 ? balance : 0) ||
        money('credit') != (balance < 0 ? -balance : 0)) {
      throw const FormatException('Invalid account balance');
    }
    var sequence = after;
    final ids = <String>{};
    for (final value in items) {
      final entry = RemoteJson(value);
      FinancialReportPage.uuid(entry.text('entryId'));
      FinancialReportPage.uuid(entry.text('referenceId'));
      FinancialReportPage.date(entry.text('createdAt'));
      entry.text('reason');
      entry.text('referenceType');
      if (entry.number('businessId') != businessId ||
          entry.text('partyType') != type ||
          entry.text('partyId') != id ||
          entry.text('accountId') != account ||
          entry.number('sequence') <= sequence ||
          !ids.add(entry.text('entryId'))) {
        throw const FormatException('Invalid account entry');
      }
      FinancialReportPage.money(value['delta']);
      FinancialReportPage.money(value['balance']);
      sequence = entry.number('sequence');
    }
    if (next != null && (items.isEmpty || next != sequence || next! <= after)) {
      throw const FormatException('Invalid account cursor');
    }
  }
  int money(String key) => FinancialReportPage.money(summary[key]);
}

class PartyAccountFX {
  final BusinessContext context;
  final String type, id;
  final String? branch;
  PartyAccountFX(this.context, this.type, this.id)
    : branch = context.selectedBranch?.branchId;
  bool get canCreatePayment {
    if (branch == null) return false;
    final access = TreasuryFX.forContext(context, branch!);
    return access.has('accounting.payment.create', business: true) &&
        access.has('accounting.payment.allocate') &&
        access.has('accounting.treasury.use');
  }

  void check() {
    context.check();
    if (branch == null || context.selectedBranch?.branchId != branch) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  Future<void> authorize(String permission) async {
    check();
    FinancialReportPage.uuid(id);
    if (!['CUSTOMER', 'SUPPLIER'].contains(type)) {
      throw const FormatException('Invalid account party');
    }
    final access = TreasuryFX.forContext(context, branch!);
    await access.authorize();
    check();
    if (!access.has(permission, business: true)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
  }

  void party(int businessId, String partyType, String partyId) {
    if (businessId != context.session.business.businessId ||
        partyType != type ||
        partyId != id) {
      throw const FormatException('Unexpected account document party');
    }
  }

  Future<({List<InvoiceSettlementSource> items, String? next})> sources({
    String? after,
  }) async {
    await authorize('accounting.account.read');
    final page = RemoteJson(
      await context.request(
        'GET',
        '/v1/businesses/${context.session.business.businessId}/accounting/sources',
        query: {
          'partyType': type,
          'partyId': id,
          'status': 'ACTIVE',
          'limit': '50',
          'after': ?after,
        },
      ),
    );
    check();
    if (page.number('businessId') != context.session.business.businessId) {
      throw const FormatException('Unexpected source business');
    }
    final items = page.items('items', InvoiceSettlementSource.fromJson);
    final ids = <String>{};
    for (final row in items) {
      party(row.businessId, row.partyType, row.partyId);
      if (row.status != 'ACTIVE' ||
          !ids.add(row.id) ||
          after != null && row.id.compareTo(after) <= 0) {
        throw const FormatException('Invalid account source');
      }
    }
    final next = page.optionalText('nextCursor');
    if (next != null && (items.isEmpty || next != items.last.id)) {
      throw const FormatException('Invalid source cursor');
    }
    return (items: items, next: next);
  }

  Future<({List<InvoicePartyPayment> items, String? next})> payments({
    String? after,
  }) async {
    await authorize('accounting.payment.read');
    final page = RemoteJson(
      await context.request(
        'GET',
        '/v1/businesses/${context.session.business.businessId}/accounting/v2/payments',
        query: {
          'partyType': type,
          'partyId': id,
          'limit': '50',
          'after': ?after,
        },
      ),
    );
    check();
    if (page.number('businessId') != context.session.business.businessId) {
      throw const FormatException('Unexpected payment business');
    }
    final items = page.items('items', InvoicePartyPayment.fromJson);
    final ids = <String>{};
    for (final row in items) {
      party(row.businessId, row.partyType, row.partyId);
      if (!ids.add(row.id) || after != null && row.id.compareTo(after) <= 0) {
        throw const FormatException('Invalid account payment');
      }
    }
    final next = page.optionalText('nextCursor');
    if (next != null && (items.isEmpty || next != items.last.id)) {
      throw const FormatException('Invalid payment cursor');
    }
    return (items: items, next: next);
  }

  Future<RemoteInvoiceDetail> invoice(String referenceId) async {
    check();
    FinancialReportPage.uuid(referenceId);
    Future<RemoteInvoiceDetail> read(String invoiceId) async {
      final row = RemoteJson(
        await context.request(
          'GET',
          '/v1/businesses/${context.session.business.businessId}/accounting/v2/invoices/$invoiceId',
        ),
      );
      check();
      final detail = RemoteInvoiceDetail.fromJson(row.value['invoice']);
      party(
        row.number('businessId'),
        detail.summary.partyType,
        detail.summary.partyId,
      );
      if (detail.businessId != context.session.business.businessId ||
          detail.summary.id != invoiceId) {
        throw const FormatException('Unexpected account invoice');
      }
      if (detail.branchId != branch) {
        throw const AuthError(409, 'ACCOUNT_DOCUMENT_OTHER_BRANCH');
      }
      return detail;
    }

    final source = await read(referenceId);
    final root = source.summary.id == source.summary.rootId
        ? source
        : await read(source.summary.rootId);
    if (!['SALE', 'PURCHASE', 'PROFORMA'].contains(root.summary.type)) {
      throw const AuthError(409, 'ACCOUNT_DOCUMENT_UNSUPPORTED');
    }
    return root;
  }

  Future<PartyAccountPage> page({int after = 0}) async {
    check();
    FinancialReportPage.uuid(id);
    if (!['CUSTOMER', 'SUPPLIER'].contains(type) || after < 0) {
      throw const FormatException('Invalid account request');
    }
    final access = TreasuryFX.forContext(context, branch!);
    await access.authorize();
    if (!access.has('accounting.account.read', business: true)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final value = await context.auth.request(
      'GET',
      '/v1/businesses/${access.businessId}/accounting/accounts/$type/$id',
      branchId: branch,
      query: {'afterSequence': '$after', 'limit': '50'},
    );
    check();
    return PartyAccountPage(value, access.businessId, type, id, after: after);
  }
}
