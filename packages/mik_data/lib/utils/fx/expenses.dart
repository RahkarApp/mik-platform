import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/expense.dart';
import '../../source/remote/models/remote_json.dart';
import 'business_context.dart';
import 'sale_invoice.dart';
import 'treasury.dart';

class ExpenseCommand {
  final String action, key, _body;
  final String? _before;
  bool attempted;
  Map<String, dynamic> get body => jsonDecode(_body) as Map<String, dynamic>;
  Map<String, dynamic>? get before =>
      _before == null ? null : jsonDecode(_before) as Map<String, dynamic>;
  ExpenseCommand(
    this.action,
    Map<String, dynamic> body, {
    Map<String, dynamic>? before,
  }) : key = const Uuid().v4(),
       _body = jsonEncode(body),
       _before = before == null ? null : jsonEncode(before),
       attempted = false;
  ExpenseCommand.fromJson(Object? value) : this._(RemoteJson(value));
  ExpenseCommand._(RemoteJson row)
    : action = row.text('action'),
      key = row.text('key'),
      _body = jsonEncode(RemoteJson(row.value['body']).value),
      _before = row.value['before'] == null
          ? null
          : jsonEncode(row.value['before']),
      attempted = row.flag('attempted') {
    if (!Uuid.isValidUUID(fromString: key) ||
        !ExpensesFX.paths.containsKey(action)) {
      throw const FormatException('Invalid saved expense command');
    }
  }
  Map<String, Object?> toJson() => {
    'action': action,
    'key': key,
    'body': body,
    'before': before,
    'attempted': attempted,
  };
}

class ExpensesFX {
  final BusinessContext context;
  final String branchId;
  final FlutterSecureStorage storage;
  late final access = TreasuryFX.forContext(context, branchId);
  ExpenseCommand? pending;
  bool _sending = false;
  ExpensesFX(this.context, {this.storage = const FlutterSecureStorage()})
    : branchId = context.selectedBranch?.branchId ?? '';
  static const paths = {
    'create': 'expenses',
    'amend': 'expenses/amend',
    'cancel': 'expenses/cancel',
    'payment': 'expenses/payments',
    'reverse': 'expenses/payments/reverse',
    'cheque': 'expenses/cheques/status',
    'category-create': 'expenses/categories',
    'category-update': 'expenses/categories/update',
  };
  static const codes = {
    'create': 'accounting.expense.create',
    'amend': 'accounting.expense.update',
    'cancel': 'accounting.expense.delete',
    'payment': 'accounting.expense.payment.pay',
    'reverse': 'accounting.expense.payment.reverse',
    'cheque': 'accounting.cheque.clear',
    'category-create': 'accounting.expense.category.create',
    'category-update': 'accounting.expense.category.update',
  };
  int get businessId => context.session.business.businessId;
  String get base => '/v1/businesses/$businessId/accounting';
  String get _key =>
      'expenses.v1.${context.auth.appId}.${context.origin}.${context.session.identityId}.$businessId.$branchId';
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

  bool has(String code, {bool business = false}) =>
      access.has(code, business: business);
  bool can(String action) =>
      has(codes[action]!, business: action.startsWith('category-'));
  bool own(RemoteExpense row, String action) {
    if (row.json['loanId'] != null || row.json['payoutId'] != null) {
      return false;
    }
    if (['amend', 'cancel'].contains(action) &&
        row.json['capitalizedAssetId'] != null) {
      return false;
    }
    return context.session.business.membershipType == 'OWNER' ||
        RemoteJson(row.json['createdBy']).optionalText('identityId') ==
            context.session.identityId ||
        has(
          'accounting.expense.${action == 'cancel' ? 'delete' : 'update'}.all',
        );
  }

  Future<Object?> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? data,
    String? key,
  }) async {
    check();
    final result = await context.auth.request(
      method,
      '$base/$path',
      branchId: branchId,
      query: query,
      data: data,
      idempotencyKey: key,
    );
    check();
    return result;
  }

  RemoteExpense parse(Object? value) {
    final row = RemoteExpense(value);
    if (row.json['businessId'] != businessId ||
        row.json['branchId'] != branchId) {
      throw const FormatException('Unexpected expense scope');
    }
    return row;
  }

  ExpenseCategory category(Object? value) {
    final row = ExpenseCategory(value);
    if (row.json['businessId'] != businessId) {
      throw const FormatException('Unexpected category business');
    }
    return row;
  }

  ExpenseDisbursement payment(Object? value, RemoteExpense parent) {
    final row = ExpenseDisbursement(value);
    if (row.json['businessId'] != businessId ||
        row.json['branchId'] != branchId ||
        row.json['expenseId'] != parent.id ||
        row.json['payeeId'] != parent.json['payeeId']) {
      throw const FormatException('Unexpected expense payment scope');
    }
    return row;
  }

  Future<List<T>> pages<T>(
    String path,
    T Function(Object?) parse,
    String Function(T) id, {
    Map<String, String> query = const {},
  }) async {
    final rows = <T>[], ids = <String>{}, cursors = <String>{};
    String? after;
    do {
      final page = RemoteJson(
        await request(
          'GET',
          path,
          query: {...query, 'limit': '100', 'after': ?after},
        ),
      );
      if (page.number('businessId') != businessId) {
        throw const FormatException('Unexpected expense page');
      }
      for (final row in page.items('items', parse)) {
        if (!ids.add(id(row))) {
          throw const FormatException('Repeated expense row');
        }
        rows.add(row);
      }
      after = page.optionalText('nextCursor');
      if (after != null &&
          (!Uuid.isValidUUID(fromString: after) || !cursors.add(after))) {
        throw const FormatException('Invalid expense cursor');
      }
    } while (after != null);
    return rows;
  }

  Future<List<RemoteExpense>> all() async {
    if (!has('accounting.expense.read')) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    return pages('expenses', parse, (row) => row.id);
  }

  Future<List<ExpenseCategory>> categories() async {
    if (!has('accounting.expense.category.read', business: true)) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    return pages('expenses/categories', category, (row) => row.id);
  }

  Future<RemoteExpense> get(String id) async {
    await authorize();
    if (!has('accounting.expense.read')) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final result = RemoteJson(
      await request('GET', 'expenses/${Uri.encodeComponent(id)}'),
    );
    final row = parse(result.value['item']);
    if (result.number('businessId') != businessId || row.id != id) {
      throw const FormatException('Unexpected expense detail');
    }
    return row;
  }

  Future<List<ExpenseDisbursement>> payments(RemoteExpense row) => pages(
    'expenses/payments',
    (v) => payment(v, row),
    (v) => v.id,
    query: {'expenseId': row.id},
  );
  Future<List<SalePaymentTarget>> targets(String method) async {
    if (!has('accounting.treasury.use') ||
        method != 'CASH' && !access.canUseBank) {
      throw const AuthError(403, 'FORBIDDEN');
    }
    final rows = await pages(
      'treasury/options',
      (v) => SalePaymentTarget.fromJson(v, terminal: false),
      (r) => r.id,
      query: {'kind': 'fund'},
    );
    if (rows.any((r) => r.branchId != null && r.branchId != branchId)) {
      throw const FormatException('Unexpected expense fund branch');
    }
    return rows
        .where(
          (r) => method == 'CASH'
              ? ['CASH', 'PETTY_CASH'].contains(r.kind)
              : r.kind == 'BANK',
        )
        .toList();
  }

  Future<ExpenseCommand?> restore() async {
    check();
    if (_sending) return pending;
    final saved = await storage.read(key: _key);
    check();
    return pending = saved == null
        ? null
        : ExpenseCommand.fromJson(jsonDecode(saved));
  }

  Future<void> send(ExpenseCommand command) async {
    if (_sending) throw const AuthError(409, 'EXPENSE_PENDING');
    _sending = true;
    try {
      if (pending == null) {
        final saved = await storage.read(key: _key);
        check();
        if (saved != null) pending = ExpenseCommand.fromJson(jsonDecode(saved));
      }
      if (pending != null && pending!.key != command.key) {
        throw const AuthError(409, 'EXPENSE_PENDING');
      }
      await authorize();
      if (!can(command.action)) throw const AuthError(403, 'FORBIDDEN');
      final body = RemoteJson(command.body);
      RemoteExpense? before;
      if (![
        'create',
        'category-create',
        'category-update',
      ].contains(command.action)) {
        before = parse(RemoteJson(command.before).value['expense']);
        if (!own(before, command.action)) {
          throw const AuthError(403, 'FORBIDDEN');
        }
        if (['amend', 'cancel', 'payment'].contains(command.action) &&
            (body.text('expenseId') != before.id ||
                body.number('expectedRevision') != before.revision)) {
          throw const FormatException('Unexpected expense command');
        }
      }
      if (command.action == 'cheque' &&
          !has('accounting.expense.payment.pay')) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      if (command.action == 'payment' &&
          RemoteJson(body.value['payment']).text('method') == 'CHEQUE' &&
          !has('accounting.expense.cheque.pay')) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      final previousAttempt = command.attempted;
      pending = command;
      command.attempted = true;
      await storage.write(key: _key, value: jsonEncode(command.toJson()));
      try {
        final result = RemoteJson(
          await request(
            'POST',
            paths[command.action]!,
            data: body.value,
            key: command.key,
          ),
        );
        if (result.number('businessId') != businessId) {
          throw const FormatException('Unexpected saved expense business');
        }
        if (command.action.startsWith('category-')) {
          final row = category(result.value['item']);
          if (row.name != body.text('name') ||
              command.action == 'category-update' &&
                  (row.id != body.text('categoryId') ||
                      RemoteJson(row.json).number('revision') <=
                          body.number('expectedRevision') ||
                      row.status != body.text('status'))) {
            throw const FormatException('Unexpected saved category');
          }
        } else {
          final row = parse(result.value['expense']);
          if (['create', 'amend'].contains(command.action) &&
              row.status != 'ISSUED') {
            throw const FormatException('Expense was not issued');
          }
          if (before != null &&
              (row.id != before.id || row.revision <= before.revision)) {
            throw const FormatException('Unexpected saved expense');
          }
          if (command.action == 'cancel' && row.status != 'VOIDED') {
            throw const FormatException('Expense not voided');
          }
          for (final field in [
            'title',
            'amount',
            'categoryId',
            'payeeId',
            'note',
          ]) {
            if (body.value.containsKey(field) &&
                row.json[field] != body.value[field]) {
              throw const FormatException('Unexpected expense values');
            }
          }
          if (['payment', 'reverse', 'cheque'].contains(command.action)) {
            final paid = payment(result.value['disbursement'], row);
            if (command.action == 'payment') {
              final input = RemoteJson(body.value['payment']);
              if (paid.json['amount'] != input.number('amount') ||
                  paid.method != input.text('method') ||
                  paid.status !=
                      (paid.method == 'CHEQUE' ? 'PENDING' : 'CONFIRMED') ||
                  RemoteJson(paid.json['routing']).text('fundId') !=
                      RemoteJson(input.value['routing']).text('fundId')) {
                throw const FormatException(
                  'Unexpected disbursement confirmation',
                );
              }
              if (paid.method == 'CHEQUE') {
                final cheque = RemoteJson(paid.json['cheque']),
                    expected = RemoteJson(input.value['cheque']);
                for (final key in [
                  'bankName',
                  'number',
                  'sayadId',
                  'drawerName',
                ]) {
                  if (cheque.value[key] != expected.value[key]) {
                    throw const FormatException('Unexpected cheque data');
                  }
                }
                if (DateTime.parse(cheque.text('dueAt')) !=
                    DateTime.parse(expected.text('dueAt'))) {
                  throw const FormatException('Unexpected cheque due date');
                }
              }
            } else {
              final old = payment(
                RemoteJson(command.before).value['payment'],
                before!,
              );
              if (paid.id != old.id ||
                  paid.id != body.text('disbursementId') ||
                  body.number('expectedRevision') != old.json['revision'] ||
                  RemoteJson(paid.json).number('revision') <=
                      RemoteJson(old.json).number('revision') ||
                  paid.status !=
                      (command.action == 'reverse'
                          ? 'REVERSED'
                          : body.text('status')) ||
                  paid.json['amount'] != old.json['amount'] ||
                  RemoteJson(paid.json['routing']).text('fundId') !=
                      RemoteJson(old.json['routing']).text('fundId')) {
                throw const FormatException('Unexpected payment correction');
              }
            }
          }
        }
        await storage.delete(key: _key);
        pending = null;
      } on AuthError catch (error) {
        if (!previousAttempt &&
            error.statusCode < 500 &&
            !error.retryable &&
            !error.requiresLogin &&
            error.statusCode != 403 &&
            ![
              'IDEMPOTENCY_CONFLICT',
              'SELECTION_CHANGED',
            ].contains(error.code)) {
          await storage.delete(key: _key);
          pending = null;
        }
        rethrow;
      }
    } finally {
      _sending = false;
    }
  }

  static String message(Object failure) {
    if (failure is AuthError) {
      switch (failure.code) {
        case 'EXPENSE_PENDING':
          return 'درخواست قبلی هزینه تعیین تکلیف نشده است؛ همان درخواست را پیگیری کنید.';
        case 'SETTLEMENT_EXCEEDED':
          return 'مبلغ از مانده بدون پرداخت و چک در انتظار بیشتر است؛ اطلاعات را تازه کنید.';
        case 'RECORD_IN_USE':
          return 'پرداخت‌های هزینه باید تعیین تکلیف شوند؛ هزینه‌های وابسته به وام، دارایی یا تسویه از بخش اصلی خود پیگیری می‌شوند.';
        case 'DUPLICATE_RECORD':
          return 'رکورد تکراری است؛ شناسه صیاد یا مشخصات واردشده را بررسی کنید.';
        case 'FORBIDDEN':
          return 'مجوز این هزینه، عملیات پرداخت یا استفاده از منبع پرداخت را ندارید.';
        case 'VALIDATION_FAILED':
          return 'عنوان، مبلغ به تومان، دسته‌بندی، سرویس‌دهنده، تاریخ و اطلاعات پرداخت را بررسی کنید.';
        case 'REVISION_CONFLICT':
          return 'هزینه یا پرداخت تغییر کرده است؛ اطلاعات تازه را دریافت و دوباره بررسی کنید.';
        case 'INVALID_STATE':
          return 'وضعیت فعلی هزینه یا پرداخت اجازه این عملیات را نمی‌دهد.';
        case 'INSUFFICIENT_FUNDS':
          return 'موجودی منبع پرداخت کافی نیست.';
      }
    }
    return SaleInvoiceFX.message(failure);
  }
}
