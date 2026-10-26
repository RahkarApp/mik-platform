import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/financial_report.dart';
import '../../source/remote/models/loan.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';
import 'sale_invoice.dart';
import 'treasury.dart';

class LoanCommand {
  final String action, key, _body;
  final String? _before;
  bool attempted;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  Map<String, dynamic>? get before =>
      _before == null ? null : jsonDecode(_before) as Map<String, dynamic>;
  LoanCommand(
    this.action,
    Map<String, dynamic> body, {
    Map<String, dynamic>? before,
  }) : key = const Uuid().v4(),
       _body = jsonEncode(body),
       _before = before == null ? null : jsonEncode(before),
       attempted = false;
  LoanCommand.fromJson(Object? value) : this._(RemoteJson(value));
  LoanCommand._(RemoteJson row)
    : action = row.text('action'),
      key = row.text('key'),
      _body = jsonEncode(RemoteJson(row.value['body']).value),
      _before = row.value['before'] == null
          ? null
          : jsonEncode(RemoteJson(row.value['before']).value),
      attempted = row.flag('attempted') {
    FinancialReportPage.uuid(key);
    if (!LoansFX.permissions.containsKey(action)) {
      throw const FormatException('Invalid loan command');
    }
  }
  Map<String, dynamic> toJson() => {
    'action': action,
    'key': key,
    'body': body,
    'before': before,
    'attempted': attempted,
  };
}

class LoansFX {
  final BusinessContext context;
  final String branchId;
  final FlutterSecureStorage storage;
  late final access = TreasuryFX.forContext(context, branchId);
  LoanCommand? pending;
  bool sending = false;
  LoansFX(this.context, {this.storage = const FlutterSecureStorage()})
    : branchId = context.selectedBranch?.branchId ?? '';
  static const permissions = {
    'create': 'manage',
    'fund': 'fund',
    'payment': 'pay',
    'cancel': 'manage',
    'reschedule': 'manage',
    'waive': 'waive',
    'reverse': 'reverse',
    'cheque': 'pay',
  };
  int get businessId => context.session.business.businessId;
  String get _key =>
      'loans.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId';
  void check() {
    context.check();
    if (branchId.isEmpty || context.selectedBranch?.branchId != branchId) {
      throw const AuthError(409, 'SELECTION_CHANGED');
    }
  }

  bool has(String code) => access.has('accounting.loan.$code', business: true);
  Future<void> authorize() async {
    check();
    await access.authorize();
    check();
    if (!has('read')) throw const AuthError(403, 'FORBIDDEN');
  }

  Future<RemoteJson> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? data,
    String? key,
  }) async {
    check();
    final result = RemoteJson(
      await context.auth.request(
        method,
        '/v1/businesses/$businessId/accounting/$path',
        branchId: branchId,
        query: query,
        data: data,
        idempotencyKey: key,
      ),
    );
    check();
    if (result.number('businessId') != businessId) {
      throw const FormatException('Unexpected loan business');
    }
    return result;
  }

  RemoteLoan parse(Object? value, {bool presented = true}) {
    final row = RemoteLoan(value, presented: presented);
    if (row.json['businessId'] != businessId) {
      throw const FormatException('Unexpected loan scope');
    }
    return row;
  }

  Future<List<RemoteLoan>> all() async {
    await authorize();
    final result = <RemoteLoan>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final page = await request(
        'GET',
        'loans',
        query: {'limit': '100', 'after': ?after},
      );
      final rows = page.items('items', (v) => parse(v));
      for (final row in rows) {
        if (!ids.add(row.id)) throw const FormatException('Repeated loan');
      }
      result.addAll(rows);
      after = page.optionalText('nextCursor');
      if (after != null &&
          (rows.isEmpty || after != rows.last.id || !cursors.add(after))) {
        throw const FormatException('Invalid loan cursor');
      }
    } while (after != null);
    return result;
  }

  List<LoanInstallment> installments(RemoteJson page, String id) {
    final rows = page.items('installments', LoanInstallment.new),
        ids = <String>{},
        numbers = <int>{};
    if (rows.isEmpty || rows.length > 120) {
      throw const FormatException('Invalid loan schedule');
    }
    for (final row in rows) {
      if (row.json['businessId'] != businessId ||
          row.json['loanId'] != id ||
          !ids.add(row.id) ||
          !numbers.add(row.json['number'] as int)) {
        throw const FormatException('Unexpected installment scope');
      }
    }
    return rows;
  }

  Future<({RemoteLoan loan, List<LoanInstallment> installments})> detail(
    String id,
  ) async {
    FinancialReportPage.uuid(id);
    await authorize();
    final page = await request('GET', 'loans/$id'),
        loan = parse(page.value['item']);
    if (loan.id != id) throw const FormatException('Unexpected loan identity');
    return (loan: loan, installments: installments(page, id));
  }

  Future<List<LoanPayment>> payments(String id) async {
    FinancialReportPage.uuid(id);
    final result = <LoanPayment>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final page = await request(
        'GET',
        'loans/payments',
        query: {'loanId': id, 'limit': '100', 'after': ?after},
      );
      final rows = page.items('items', LoanPayment.new);
      for (final row in rows) {
        if (row.json['businessId'] != businessId ||
            row.json['loanId'] != id ||
            !ids.add(row.json['loanPaymentId'] as String)) {
          throw const FormatException('Unexpected loan payment');
        }
      }
      result.addAll(rows);
      after = page.optionalText('nextCursor');
      if (after != null &&
          (rows.isEmpty ||
              after != rows.last.json['loanPaymentId'] ||
              !cursors.add(after))) {
        throw const FormatException('Invalid payment cursor');
      }
    } while (after != null);
    return result;
  }

  Future<List<SalePaymentTarget>> targets(String method) async {
    if (!['CASH', 'BANK_TRANSFER', 'CHEQUE'].contains(method)) {
      throw const FormatException('Unsupported loan method');
    }
    if (!access.has('accounting.treasury.use') ||
        method != 'CASH' && !access.canUseBank) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final result = <SalePaymentTarget>[],
        ids = <String>{},
        cursors = <String>{};
    String? after;
    do {
      final page = await request(
        'GET',
        'treasury/options',
        query: {'kind': 'fund', 'limit': '100', 'after': ?after},
      );
      final rows = page.items(
        'items',
        (v) => SalePaymentTarget.fromJson(v, terminal: false),
      );
      for (final row in rows) {
        if (!ids.add(row.id) ||
            row.branchId != null && row.branchId != branchId) {
          throw const FormatException('Unexpected loan fund');
        }
        if (row.accepts(method == 'CHEQUE' ? 'BANK_TRANSFER' : method)) {
          result.add(row);
        }
      }
      after = page.optionalText('nextCursor');
      if (after != null &&
          (rows.isEmpty || after != rows.last.id || !cursors.add(after))) {
        throw const FormatException('Invalid fund cursor');
      }
    } while (after != null);
    return result;
  }

  Future<LoanCommand?> restore() async {
    check();
    final value = await storage.read(key: _key);
    check();
    return pending = value == null
        ? null
        : LoanCommand.fromJson(jsonDecode(value));
  }

  Future<RemoteLoan> send(LoanCommand command) async {
    if (sending) throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
    sending = true;
    try {
      await restore();
      if (pending != null && pending!.key != command.key) {
        throw const AuthError(409, 'IDEMPOTENCY_CONFLICT');
      }
      await authorize();
      final permission = permissions[command.action];
      if (permission == null || !has(permission)) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      if ([
        'reschedule',
        'waive',
        'reverse',
        'cheque',
      ].contains(command.action)) {
        return await _manage(command);
      }
      final body = RemoteJson(command.body),
          create = command.action == 'create',
          fund = command.action == 'fund',
          pay = command.action == 'payment';
      RemoteLoan? before;
      List<LoanInstallment> schedule = [];
      if (create) {
        if (body.value.keys.any(
              (k) => ![
                'name',
                'direction',
                'counterparty',
                'partnerId',
                'principalAmount',
                'contractChargeAmount',
                'installments',
                'note',
              ].contains(k),
            ) ||
            body.text('name').trim().isEmpty ||
            body.text('name').length > 200 ||
            !loanDirections.containsKey(body.text('direction'))) {
          throw const FormatException('Invalid loan fields');
        }
        final party = RemoteJson(body.value['counterparty']);
        if (party.text('name').trim().isEmpty ||
            party.text('name').length > 200 ||
            party.value.keys.any(
              (k) => !['name', 'phone', 'reference'].contains(k),
            )) {
          throw const FormatException('Invalid counterparty');
        }
        for (final field in ['phone', 'reference']) {
          if (party.value.containsKey(field) &&
              party.text(field).length > 100) {
            throw const FormatException('Invalid counterparty reference');
          }
        }
        if (body.value['partnerId'] != null) {
          FinancialReportPage.uuid(body.text('partnerId'));
        }
        if (body.value.containsKey('note') && body.text('note').length > 1000) {
          throw const FormatException('Invalid note');
        }
        final principal = FinancialReportPage.money(
              body.value['principalAmount'],
              nonnegative: true,
            ),
            charge = FinancialReportPage.money(
              body.value['contractChargeAmount'],
              nonnegative: true,
            );
        final rows = body.items('installments', RemoteJson.new);
        var p = 0, c = 0;
        DateTime? previous;
        if (principal <= 0 || rows.isEmpty || rows.length > 120) {
          throw const FormatException('Invalid loan plan');
        }
        for (final row in rows) {
          final on = DateTime.parse(row.text('dueAt')),
              rp = FinancialReportPage.money(
                row.value['principalAmount'],
                nonnegative: true,
              ),
              rc = FinancialReportPage.money(
                row.value['chargeAmount'],
                nonnegative: true,
              );
          if (row.value.keys.any(
                (k) =>
                    !['dueAt', 'principalAmount', 'chargeAmount'].contains(k),
              ) ||
              rp + rc <= 0 ||
              previous != null && on.isBefore(previous)) {
            throw const FormatException('Invalid installment plan');
          }
          previous = on;
          p += rp;
          c += rc;
        }
        if (p != principal || c != charge) {
          throw const FormatException(
            'Installment totals differ from contract',
          );
        }
      } else {
        final snapshot = RemoteJson(command.before);
        before = parse(snapshot.value['loan']);
        schedule = installments(snapshot, before.id);
        if (body.text('loanId') != before.id ||
            body.number('expectedRevision') != before.revision ||
            before.status != (pay ? 'ACTIVE' : 'DRAFT')) {
          throw const FormatException('Invalid loan operation');
        }
        final allowed = fund
            ? [
                'loanId',
                'expectedRevision',
                'method',
                'routing',
                'fundsConfirmed',
                'occurredAt',
                'reference',
                'reason',
              ]
            : pay
            ? [
                'loanId',
                'expectedRevision',
                'payment',
                'occurredAt',
                'allocations',
                'recognizeFutureCharges',
              ]
            : ['loanId', 'expectedRevision', 'reason'];
        if (body.value.keys.any((k) => !allowed.contains(k))) {
          throw const FormatException('Unsupported loan operation fields');
        }
        if (!pay &&
            (body.text('reason').trim().isEmpty ||
                body.text('reason').length > 500)) {
          throw const FormatException('Invalid loan reason');
        }
        if (fund || pay) {
          final on = DateTime.parse(body.text('occurredAt'));
          if (on.isAfter(DateTime.now().toUtc()) ||
              fund &&
                  schedule.any(
                    (s) =>
                        DateTime.parse(s.json['dueAt'] as String).isBefore(on),
                  ) ||
              pay &&
                  on.isBefore(
                    DateTime.parse(before.json['fundedAt'] as String),
                  )) {
            throw const FormatException('Invalid loan date');
          }
          final payment = pay ? RemoteJson(body.value['payment']) : body;
          if (pay &&
                  payment.value.keys.any(
                    (k) => ![
                      'amount',
                      'method',
                      'routing',
                      'confirmed',
                      'transactionReference',
                      'note',
                      'cheque',
                    ].contains(k),
                  ) ||
              payment.value[pay ? 'confirmed' : 'fundsConfirmed'] != true ||
              !(pay
                      ? ['CASH', 'BANK_TRANSFER', 'CHEQUE']
                      : ['CASH', 'BANK_TRANSFER'])
                  .contains(payment.text('method'))) {
            throw const FormatException('Confirm actual loan transfer');
          }
          if (pay &&
              FinancialReportPage.money(
                    payment.value['amount'],
                    nonnegative: true,
                  ) <=
                  0) {
            throw const FormatException('Invalid repayment amount');
          }
          if (pay) {
            if (body.value.containsKey('recognizeFutureCharges') &&
                body.value['recognizeFutureCharges'] is! bool) {
              throw const FormatException('Invalid future charge confirmation');
            }
            if (body.value.containsKey('allocations')) {
              final requested = body.items('allocations', RemoteJson.new);
              final ids = <String>{};
              var total = 0;
              if (requested.isEmpty || requested.length > 120) {
                throw const FormatException('Invalid installment allocations');
              }
              for (final part in requested) {
                final id = part.text('loanInstallmentId');
                final row = schedule.where((s) => s.id == id).firstOrNull;
                final principal = FinancialReportPage.money(
                  part.value['principalAmount'],
                  nonnegative: true,
                );
                final charge = FinancialReportPage.money(
                  part.value['chargeAmount'],
                  nonnegative: true,
                );
                if (part.value.keys.any(
                      (k) => ![
                        'loanInstallmentId',
                        'principalAmount',
                        'chargeAmount',
                      ].contains(k),
                    ) ||
                    row == null ||
                    !ids.add(id) ||
                    principal + charge <= 0 ||
                    principal >
                        row.money('principalAmount') -
                            row.money('paidPrincipalAmount') -
                            row.money('pendingPrincipalAmount') ||
                    charge >
                        row.money('chargeAmount') -
                            row.money('waivedChargeAmount') -
                            row.money('paidChargeAmount') -
                            row.money('pendingChargeAmount')) {
                  throw const FormatException(
                    'Invalid installment allocation balance',
                  );
                }
                // The server recognizes due charges before allocating, using its current time.
                final accrued =
                    DateTime.parse(row.json['dueAt'] as String)
                        .isAfter(DateTime.now().toUtc())
                    ? row.money('accruedChargeAmount')
                    : row.money('chargeAmount') -
                          row.money('waivedChargeAmount');
                final available =
                    accrued -
                    row.money('paidChargeAmount') -
                    row.money('pendingChargeAmount');
                if (charge > (available < 0 ? 0 : available) &&
                    body.value['recognizeFutureCharges'] != true) {
                  throw const FormatException('Confirm agreed future charges');
                }
                total += principal + charge;
              }
              if (total != payment.number('amount') ||
                  total > 9007199254740991) {
                throw const FormatException(
                  'Allocations must equal payment amount',
                );
              }
            } else if (body.value['recognizeFutureCharges'] == true) {
              throw const FormatException(
                'Future charges require explicit allocations',
              );
            }
          }
          for (final field
              in pay ? ['transactionReference', 'note'] : ['reference']) {
            if (payment.value.containsKey(field) &&
                payment.text(field).length > (field == 'note' ? 1000 : 200)) {
              throw const FormatException('Invalid loan reference');
            }
          }
          if (!access.has('accounting.treasury.use') ||
              payment.text('method') != 'CASH' && !access.canUseBank) {
            throw const AuthError(403, 'FORBIDDEN');
          }
          if (payment.text('method') == 'CHEQUE') {
            final cheque = RemoteJson(payment.value['cheque']);
            if (cheque.value.keys.any(
                  (k) => ![
                    'bankName',
                    'number',
                    'dueAt',
                    'sayadId',
                    'drawerName',
                  ].contains(k),
                ) ||
                cheque.text('bankName').trim().isEmpty ||
                cheque.text('bankName').length > 100 ||
                cheque.text('number').trim().isEmpty ||
                cheque.text('number').length > 64 ||
                cheque.value.containsKey('sayadId') &&
                    !RegExp(r'^\d{16}$').hasMatch(cheque.text('sayadId')) ||
                cheque.value.containsKey('drawerName') &&
                    cheque.text('drawerName').length > 200) {
              throw const FormatException('Invalid loan cheque');
            }
            FinancialReportPage.date(cheque.text('dueAt'));
          } else if (payment.value.containsKey('cheque')) {
            throw const FormatException('Unexpected loan cheque');
          }
          final route = RemoteJson(payment.value['routing']);
          if (route.value.length != 1 || !route.value.containsKey('fundId')) {
            throw const FormatException('Invalid loan route');
          }
          FinancialReportPage.uuid(route.text('fundId'));
        }
      }
      final previous = command.attempted;
      pending = command;
      command.attempted = true;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      check();
      try {
        final response = await request(
          'POST',
          command.action == 'create'
              ? 'loans'
              : pay
              ? 'loans/payments'
              : 'loans/${command.action}',
          data: command.body,
          key: command.key,
        );
        final loan = parse(
          response.value['loan'],
          presented: command.action != 'cancel',
        );
        if (create) {
          if (loan.status != 'DRAFT' ||
              loan.json['name'] != body.value['name'] ||
              loan.json['direction'] != body.value['direction'] ||
              loan.money('principalAmount') != body.value['principalAmount'] ||
              loan.money('contractChargeAmount') !=
                  body.value['contractChargeAmount'] ||
              loan.json['fundedAt'] != null ||
              loan.json['partnerId'] != body.value['partnerId'] ||
              loan.json['note'] != body.value['note']) {
            throw const FormatException('Loan creation not confirmed');
          }
          for (final field in ['name', 'phone', 'reference']) {
            if (RemoteJson(loan.json['counterparty']).value[field] !=
                RemoteJson(body.value['counterparty']).value[field]) {
              throw const FormatException('Loan party not confirmed');
            }
          }
          for (final field in RemoteLoan.amounts.keys.where(
            (k) => !['principalAmount', 'contractChargeAmount'].contains(k),
          )) {
            if (loan.money(field) != 0) {
              throw const FormatException('Unexpected draft loan balance');
            }
          }
          final saved = installments(response, loan.id),
              requested = body.items('installments', RemoteJson.new);
          if (saved.length != requested.length) {
            throw const FormatException('Loan plan not confirmed');
          }
          for (final row in saved) {
            final index = (row.json['number'] as int) - 1;
            if (index < 0 || index >= requested.length) {
              throw const FormatException('Invalid schedule number');
            }
            final input = requested[index];
            if (DateTime.parse(row.json['dueAt'] as String).toUtc() !=
                    DateTime.parse(input.text('dueAt')).toUtc() ||
                row.money('principalAmount') !=
                    input.number('principalAmount') ||
                row.money('chargeAmount') != input.number('chargeAmount')) {
              throw const FormatException('Installment not confirmed');
            }
          }
        } else {
          if (loan.id != before!.id ||
              loan.revision <= before.revision ||
              loan.json['name'] != before.json['name'] ||
              loan.json['direction'] != before.json['direction'] ||
              loan.money('principalAmount') !=
                  before.money('principalAmount') ||
              loan.money('contractChargeAmount') !=
                  before.money('contractChargeAmount')) {
            throw const FormatException('Unexpected loan operation result');
          }
          if (fund || command.action == 'cancel') {
            if (loan.status != (fund ? 'ACTIVE' : 'CANCELLED')) {
              throw const FormatException('Loan state not confirmed');
            }
            for (final field in RemoteLoan.amounts.keys) {
              if (loan.money(field) != before.money(field)) {
                throw const FormatException('Unexpected loan balance change');
              }
            }
            if (fund) {
              final funding = RemoteJson(loan.json['funding']);
              if (DateTime.parse(loan.json['fundedAt'] as String).toUtc() !=
                      DateTime.parse(body.text('occurredAt')).toUtc() ||
                  funding.text('method') != body.text('method') ||
                  funding.text('branchId') != branchId ||
                  RemoteJson(funding.value['routing']).text('fundId') !=
                      RemoteJson(body.value['routing']).text('fundId') ||
                  funding.value['reference'] != body.value['reference']) {
                throw const FormatException('Funding not confirmed');
              }
            }
          } else {
            final payment = LoanPayment(response.value['payment']),
                input = RemoteJson(body.value['payment']);
            final pendingCheque = input.text('method') == 'CHEQUE';
            if (payment.json['businessId'] != businessId ||
                payment.json['loanId'] != before.id ||
                payment.json['branchId'] != branchId ||
                payment.json['status'] !=
                    (pendingCheque ? 'PENDING' : 'CONFIRMED') ||
                payment.money('amount') != input.number('amount') ||
                payment.json['method'] != input.text('method') ||
                DateTime.parse(payment.json['occurredAt'] as String).toUtc() !=
                    DateTime.parse(body.text('occurredAt')).toUtc() ||
                RemoteJson(payment.json['routing']).text('fundId') !=
                    RemoteJson(input.value['routing']).text('fundId') ||
                payment.json['transactionReference'] !=
                    input.value['transactionReference'] ||
                payment.json['note'] != input.value['note'] ||
                !['ACTIVE', 'SETTLED'].contains(loan.status) ||
                loan.json['fundedAt'] != before.json['fundedAt'] ||
                loan.money(
                      pendingCheque
                          ? 'pendingPrincipalAmount'
                          : 'paidPrincipalAmount',
                    ) !=
                    before.money(
                          pendingCheque
                              ? 'pendingPrincipalAmount'
                              : 'paidPrincipalAmount',
                        ) +
                        payment.money('principalAmount') ||
                loan.money(
                      pendingCheque
                          ? 'pendingChargeAmount'
                          : 'paidChargeAmount',
                    ) !=
                    before.money(
                          pendingCheque
                              ? 'pendingChargeAmount'
                              : 'paidChargeAmount',
                        ) +
                        payment.money('chargeAmount') ||
                loan.money('accruedChargeAmount') <
                    before.money('accruedChargeAmount')) {
              throw const FormatException('Repayment not confirmed');
            }
            if (body.value.containsKey('allocations')) {
              final requested = body.items('allocations', RemoteJson.new);
              final saved = RemoteJson(payment.json)
                  .items('allocations', RemoteJson.new);
              if (saved.length != requested.length) {
                throw const FormatException(
                  'Repayment allocations not confirmed',
                );
              }
              for (final part in requested) {
                final match = saved
                    .where(
                      (s) =>
                          s.text('loanInstallmentId') ==
                          part.text('loanInstallmentId'),
                    )
                    .firstOrNull;
                if (match == null ||
                    match.number('principalAmount') !=
                        part.number('principalAmount') ||
                    match.number('chargeAmount') !=
                        part.number('chargeAmount')) {
                  throw const FormatException('Repayment allocation changed');
                }
              }
            }
            if (pendingCheque) {
              final requestedCheque = RemoteJson(input.value['cheque']),
                  savedCheque = RemoteJson(payment.json['cheque']);
              for (final field in [
                'bankName',
                'number',
                'sayadId',
                'drawerName',
              ]) {
                if (savedCheque.value[field] != requestedCheque.value[field]) {
                  throw const FormatException('Loan cheque not confirmed');
                }
              }
              if (DateTime.parse(savedCheque.text('dueAt')).toUtc() !=
                  DateTime.parse(requestedCheque.text('dueAt')).toUtc()) {
                throw const FormatException('Loan cheque date not confirmed');
              }
            }
            for (final field in [
              'waivedChargeAmount',
              pendingCheque ? 'paidPrincipalAmount' : 'pendingPrincipalAmount',
              pendingCheque ? 'paidChargeAmount' : 'pendingChargeAmount',
            ]) {
              if (loan.money(field) != before.money(field)) {
                throw const FormatException('Unexpected repayment balance');
              }
            }
            for (final allocation in RemoteJson(
              payment.json,
            ).items('allocations', RemoteJson.new)) {
              final row = schedule
                  .where((s) => s.id == allocation.text('loanInstallmentId'))
                  .firstOrNull;
              if (row == null ||
                  allocation.number('principalAmount') >
                      row.money('principalAmount') -
                          row.money('paidPrincipalAmount') -
                          row.money('pendingPrincipalAmount') ||
                  allocation.number('chargeAmount') >
                      row.money('chargeAmount') -
                          row.money('waivedChargeAmount') -
                          row.money('paidChargeAmount') -
                          row.money('pendingChargeAmount')) {
                throw const FormatException('Unexpected repayment allocation');
              }
            }
          }
        }
        await storage.delete(key: _key);
        pending = null;
        return loan;
      } on AuthError catch (failure) {
        if (!previous &&
            failure.statusCode < 500 &&
            !failure.retryable &&
            !failure.requiresLogin &&
            failure.statusCode != 403 &&
            ![
              'IDEMPOTENCY_CONFLICT',
              'SELECTION_CHANGED',
            ].contains(failure.code)) {
          await storage.delete(key: _key);
          pending = null;
        }
        rethrow;
      }
    } finally {
      sending = false;
    }
  }

  Future<RemoteLoan> _manage(LoanCommand command) async {
    final snapshot = RemoteJson(command.before),
        body = RemoteJson(command.body);
    final before = parse(snapshot.value['loan']),
        schedule = installments(snapshot, before.id);
    final reschedule = command.action == 'reschedule',
        waive = command.action == 'waive',
        reverse = command.action == 'reverse';
    LoanPayment? original;
    LoanInstallment? installment;
    if (body.text('reason').trim().isEmpty ||
        body.text('reason').length > 500) {
      throw const FormatException('Invalid loan operation reason');
    }
    if (reschedule || waive) {
      if (body.text('loanId') != before.id ||
          body.number('expectedRevision') != before.revision ||
          !(waive ? ['ACTIVE'] : ['DRAFT', 'ACTIVE']).contains(before.status)) {
        throw const FormatException('Invalid open loan operation');
      }
      final allowed = waive
          ? [
              'loanId',
              'expectedRevision',
              'loanInstallmentId',
              'amount',
              'agreementConfirmed',
              'reason',
            ]
          : ['loanId', 'expectedRevision', 'installments', 'reason'];
      if (body.value.keys.any((k) => !allowed.contains(k))) {
        throw const FormatException('Unexpected loan management fields');
      }
      if (reschedule) {
        final changes = body.items('installments', RemoteJson.new),
            ids = <String>{};
        if (changes.isEmpty || changes.length > 120) {
          throw const FormatException('Invalid schedule changes');
        }
        final dueDates = {
          for (final row in schedule)
            row.id: DateTime.parse(row.json['dueAt'] as String),
        };
        for (final change in changes) {
          final id = change.text('loanInstallmentId');
          if (!dueDates.containsKey(id) ||
              !ids.add(id) ||
              change.value.keys.any(
                (k) => !['loanInstallmentId', 'dueAt'].contains(k),
              )) {
            throw const FormatException('Invalid rescheduled installment');
          }
          final on = DateTime.parse(change.text('dueAt'));
          if (before.json['fundedAt'] != null &&
              on.isBefore(DateTime.parse(before.json['fundedAt'] as String))) {
            throw const FormatException('Due date precedes funding');
          }
          dueDates[id] = on;
        }
        final ordered = [...schedule]
          ..sort(
            (a, b) =>
                (a.json['number'] as int).compareTo(b.json['number'] as int),
          );
        for (var i = 1; i < ordered.length; i++) {
          if (dueDates[ordered[i].id]!.isBefore(dueDates[ordered[i - 1].id]!)) {
            throw const FormatException('Installments must remain ordered');
          }
        }
      } else {
        installment = schedule
            .where((r) => r.id == body.text('loanInstallmentId'))
            .firstOrNull;
        final amount = FinancialReportPage.money(
          body.value['amount'],
          nonnegative: true,
        );
        if (installment == null ||
            body.value['agreementConfirmed'] != true ||
            amount <= 0 ||
            amount >
                installment.money('chargeAmount') -
                    installment.money('waivedChargeAmount') -
                    installment.money('paidChargeAmount') -
                    installment.money('pendingChargeAmount')) {
          throw const FormatException('Invalid agreed charge waiver');
        }
      }
    } else {
      original = LoanPayment(snapshot.value['payment']);
      if (original.json['businessId'] != businessId ||
          original.json['loanId'] != before.id ||
          body.text('loanPaymentId') != original.json['loanPaymentId'] ||
          body.number('expectedRevision') != original.json['revision'] ||
          (reverse
              ? original.json['status'] != 'CONFIRMED'
              : original.json['status'] != 'PENDING' ||
                    original.json['method'] != 'CHEQUE')) {
        throw const FormatException('Invalid loan payment transition');
      }
      final allowed = reverse
          ? ['loanPaymentId', 'expectedRevision', 'reason', 'fundsConfirmed']
          : [
              'loanPaymentId',
              'expectedRevision',
              'reason',
              'confirmed',
              'occurredAt',
              'status',
            ];
      if (body.value.keys.any((k) => !allowed.contains(k)) ||
          body.value[reverse ? 'fundsConfirmed' : 'confirmed'] != true) {
        throw const FormatException('Confirm actual loan payment transition');
      }
      if (!reverse) {
        if (!access.has('accounting.cheque.clear')) {
          throw const AuthError(403, 'FORBIDDEN');
        }
        final on = DateTime.parse(body.text('occurredAt'));
        if (![
              'CONFIRMED',
              'BOUNCED',
              'RETURNED',
            ].contains(body.text('status')) ||
            on.isAfter(DateTime.now().toUtc()) ||
            on.isBefore(
              DateTime.parse(original.json['occurredAt'] as String),
            )) {
          throw const FormatException('Invalid cheque result date/status');
        }
      }
      if (reverse || body.value['status'] == 'CONFIRMED') {
        if (!access.has('accounting.treasury.use') ||
            original.json['method'] != 'CASH' && !access.canUseBank) {
          throw const AuthError(403, 'FORBIDDEN');
        }
      }
    }
    final previous = command.attempted;
    pending = command;
    command.attempted = true;
    await storage.write(key: _key, value: jsonEncode(command.toJson()));
    check();
    try {
      final path = reschedule || waive
          ? 'loans/${command.action}'
          : reverse
          ? 'loans/payments/reverse'
          : 'loans/cheques/status';
      final response = await request(
            'POST',
            path,
            data: command.body,
            key: command.key,
          ),
          loan = parse(response.value['loan']);
      if (loan.id != before.id ||
          loan.json['name'] != before.json['name'] ||
          loan.json['direction'] != before.json['direction'] ||
          loan.money('principalAmount') != before.money('principalAmount') ||
          loan.money('contractChargeAmount') !=
              before.money('contractChargeAmount') ||
          loan.json['fundedAt'] != before.json['fundedAt']) {
        throw const FormatException('Unexpected managed loan');
      }
      if (reschedule || waive) {
        if (loan.revision <= before.revision) {
          throw const FormatException('Loan revision not advanced');
        }
        if (reschedule) {
          if (loan.status != before.status ||
              loan.json['scheduleReason'] != body.value['reason']) {
            throw const FormatException('Schedule not confirmed');
          }
          for (final field in RemoteLoan.amounts.keys) {
            if (loan.money(field) != before.money(field)) {
              throw const FormatException('Schedule changed loan balances');
            }
          }
          final rows = installments(response, before.id);
          if (rows.length != schedule.length) {
            throw const FormatException('Schedule lost installments');
          }
          final changes = {
            for (final c in body.items('installments', RemoteJson.new))
              c.text('loanInstallmentId'): c.text('dueAt'),
          };
          for (final row in rows) {
            final prior = schedule.where((r) => r.id == row.id).firstOrNull;
            if (prior == null ||
                row.json['number'] != prior.json['number'] ||
                changes.containsKey(row.id) &&
                    row.json['revision'] <= (prior.json['revision'] as int) ||
                DateTime.parse(row.json['dueAt'] as String).toUtc() !=
                    DateTime.parse(
                      changes[row.id] ?? prior.json['dueAt'] as String,
                    ).toUtc()) {
              throw const FormatException('Rescheduled date not confirmed');
            }
            for (final field in [
              'principalAmount',
              'chargeAmount',
              'paidPrincipalAmount',
              'paidChargeAmount',
              'pendingPrincipalAmount',
              'pendingChargeAmount',
              'accruedChargeAmount',
              'waivedChargeAmount',
            ]) {
              if (row.money(field) != prior.money(field)) {
                throw const FormatException(
                  'Schedule changed installment values',
                );
              }
            }
          }
        } else {
          final row = LoanInstallment(response.value['installment']),
              prior = installment!;
          final unrecognized =
              prior.money('chargeAmount') -
              prior.money('waivedChargeAmount') -
              prior.money('accruedChargeAmount');
          final recognized = body.number('amount') > unrecognized
              ? body.number('amount') - unrecognized
              : 0;
          if (row.id != prior.id ||
              row.json['loanId'] != before.id ||
              row.json['businessId'] != businessId ||
              row.json['revision'] <= (prior.json['revision'] as int) ||
              row.money('waivedChargeAmount') !=
                  prior.money('waivedChargeAmount') + body.number('amount') ||
              row.money('accruedChargeAmount') !=
                  prior.money('accruedChargeAmount') - recognized ||
              row.json['number'] != prior.json['number'] ||
              DateTime.parse(row.json['dueAt'] as String).toUtc() !=
                  DateTime.parse(prior.json['dueAt'] as String).toUtc() ||
              loan.money('waivedChargeAmount') !=
                  before.money('waivedChargeAmount') + body.number('amount') ||
              loan.money('accruedChargeAmount') !=
                  before.money('accruedChargeAmount') -
                      (prior.money('accruedChargeAmount') -
                          row.money('accruedChargeAmount')) ||
              !['ACTIVE', 'SETTLED'].contains(loan.status)) {
            throw const FormatException('Waiver not confirmed');
          }
          for (final field in [
            'principalAmount',
            'chargeAmount',
            'paidPrincipalAmount',
            'paidChargeAmount',
            'pendingPrincipalAmount',
            'pendingChargeAmount',
          ]) {
            if (row.money(field) != prior.money(field)) {
              throw const FormatException(
                'Waiver changed paid or reserved installment values',
              );
            }
          }
          for (final field in [
            'paidPrincipalAmount',
            'paidChargeAmount',
            'pendingPrincipalAmount',
            'pendingChargeAmount',
          ]) {
            if (loan.money(field) != before.money(field)) {
              throw const FormatException(
                'Waiver changed paid or reserved loan values',
              );
            }
          }
        }
      } else {
        final payment = LoanPayment(response.value['payment']),
            prior = original!;
        if (payment.json['loanPaymentId'] != prior.json['loanPaymentId'] ||
            payment.json['loanId'] != before.id ||
            payment.json['businessId'] != businessId ||
            payment.json['revision'] <= (prior.json['revision'] as int) ||
            payment.json['status'] !=
                (reverse ? 'REVERSED' : body.text('status')) ||
            payment.json['method'] != prior.json['method'] ||
            payment.json['branchId'] != prior.json['branchId'] ||
            payment.json['reason'] != body.value['reason'] ||
            DateTime.parse(payment.json['occurredAt'] as String).toUtc() !=
                DateTime.parse(
                  reverse
                      ? prior.json['occurredAt'] as String
                      : body.text('occurredAt'),
                ).toUtc() ||
            RemoteJson(payment.json['routing']).text('fundId') !=
                RemoteJson(prior.json['routing']).text('fundId')) {
          throw const FormatException('Loan payment transition not confirmed');
        }
        for (final field in ['amount', 'principalAmount', 'chargeAmount']) {
          if (payment.money(field) != prior.money(field)) {
            throw const FormatException(
              'Payment transition changed allocations',
            );
          }
        }
        final oldParts = RemoteJson(prior.json)
                .items('allocations', RemoteJson.new),
            parts = RemoteJson(payment.json)
                .items('allocations', RemoteJson.new);
        if (parts.length != oldParts.length) {
          throw const FormatException('Loan allocations lost');
        }
        for (final part in parts) {
          final old = oldParts
              .where(
                (p) =>
                    p.text('loanInstallmentId') ==
                    part.text('loanInstallmentId'),
              )
              .firstOrNull;
          if (old == null ||
              part.number('principalAmount') != old.number('principalAmount') ||
              part.number('chargeAmount') != old.number('chargeAmount')) {
            throw const FormatException('Loan allocation changed');
          }
        }
        for (final field in [
          'transactionReference',
          'accountReference',
          'note',
        ]) {
          if (payment.json[field] != prior.json[field]) {
            throw const FormatException('Payment metadata changed');
          }
        }
        if (prior.json['cheque'] != null) {
          final saved = RemoteJson(payment.json['cheque']),
              old = RemoteJson(prior.json['cheque']);
          for (final field in ['bankName', 'number', 'sayadId', 'drawerName']) {
            if (saved.value[field] != old.value[field]) {
              throw const FormatException('Cheque metadata changed');
            }
          }
          if (DateTime.parse(saved.text('dueAt')).toUtc() !=
              DateTime.parse(old.text('dueAt')).toUtc()) {
            throw const FormatException('Cheque due date changed');
          }
        } else if (payment.json['cheque'] != null) {
          throw const FormatException('Unexpected cheque metadata');
        }
        // These endpoints lock the payment revision, not the loan revision. Concurrent
        // payments may change loan totals; accept the validated server loan snapshot.
      }
      await storage.delete(key: _key);
      pending = null;
      return loan;
    } on AuthError catch (failure) {
      if (!previous &&
          failure.statusCode < 500 &&
          !failure.retryable &&
          !failure.requiresLogin &&
          failure.statusCode != 403 &&
          ![
            'IDEMPOTENCY_CONFLICT',
            'SELECTION_CHANGED',
          ].contains(failure.code)) {
        await storage.delete(key: _key);
        pending = null;
      }
      rethrow;
    }
  }
}
