import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/models/expense.dart';
import 'package:mik_data/source/remote/models/remote_json.dart';
import 'package:mik_data/utils/fx/expenses.dart';
import 'package:mik_data/utils/fx/sale_invoice.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

const _methods = {
  'نقدی': 'CASH',
  'واریز بانکی': 'BANK_TRANSFER',
  'کارت': 'CARD',
  'چک': 'CHEQUE',
};
const _states = {
  'PENDING': 'در انتظار',
  'CONFIRMED': 'تأییدشده',
  'BOUNCED': 'برگشتی',
  'RETURNED': 'عودت‌شده',
  'REVERSED': 'برگشت وجه',
  'WITHHELD': 'کسر از تسویه',
};
String _money(int value) => '${value.toString().seRagham()} تومان';

class ExpensePaymentScreen extends StatefulWidget {
  final ExpensesFX fx;
  final RemoteExpense expense;
  const ExpensePaymentScreen({
    required this.fx,
    required this.expense,
    super.key,
  });
  @override
  State<ExpensePaymentScreen> createState() => _ExpensePaymentScreenState();
}

class _ExpensePaymentScreenController extends GetxController {
  RemoteExpense? expense;
  List<ExpenseDisbursement> payments = [];
  List<SalePaymentTarget> targets = [];
  SalePaymentTarget? target;
  final method = 'نقدی'.obs, confirmed = 'بله'.obs;
  final amount = TextEditingController(),
      bank = TextEditingController(),
      number = TextEditingController(),
      sayad = TextEditingController(),
      drawer = TextEditingController(),
      due = TextEditingController(),
      note = TextEditingController();
  bool loading = true, saving = false;
}

class _ExpensePaymentScreenState extends State<ExpensePaymentScreen> {
  late final _page = _ExpensePaymentScreenController();

  String get code => _methods[_page.method.value]!;
  bool get canPay =>
      _page.expense != null &&
      _page.expense!.status == 'ISSUED' &&
      _page.expense!.remaining > 0 &&
      widget.fx.can('payment') &&
      widget.fx.own(_page.expense!, 'payment');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _page.amount,
      _page.bank,
      _page.number,
      _page.sayad,
      _page.drawer,
      _page.due,
      _page.note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Object> load() async {
    if (_page.saving) return '';
    {
      _page.loading = true;
      _page.expense = null;
      _page.payments = [];
      _page.targets = [];
      _page.target = null;
      _page.confirmed.value = 'بله';
      _page.update();
    }
    try {
      final row = await widget.fx.get(widget.expense.id);
      final rows = await widget.fx.payments(row);
      if (mounted) {
        {
          _page.expense = row;
          _page.payments = rows;
          _page.update();
        }
      }
      if (canPay) _page.targets = await widget.fx.targets(code);
    } catch (failure) {
      if (mounted) Alert.error(ExpensesFX.message(failure), context: context);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  Future<void> select(String value) async {
    if (_page.loading || _page.saving) return;
    {
      _page.method.value = value;
      _page.confirmed.value = 'بله';
      _page.target = null;
      _page.targets = [];
      _page.loading = true;
      _page.update();
    }
    try {
      await widget.fx.authorize();
      _page.targets = await widget.fx.targets(code);
      if (_page.targets.isEmpty && mounted) {
        Alert.error(
          'منبع فعال برای این روش پرداخت وجود ندارد.',
          context: context,
        );
      }
    } catch (failure) {
      if (mounted) Alert.error(ExpensesFX.message(failure), context: context);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  Future<void> submit() async {
    if (_page.loading || _page.saving || !canPay || widget.fx.pending != null)
      return;
    var attempted = false;
    try {
      final value = int.tryParse(
        _page.amount.text.trim().toEnglishDigit().replaceAll(',', ''),
      );
      if (value == null ||
          value <= 0 ||
          value > _page.expense!.remaining ||
          _page.target == null ||
          _page.confirmed.value != 'بله' ||
          _page.note.text.trim().length > 1000) {
        throw const FormatException('Invalid expense payment');
      }
      final input = <String, dynamic>{
        'method': code,
        'direction': 'OUT',
        'amount': value,
        'confirmed': true,
        'routing': {'fundId': _page.target!.id},
        if (_page.note.text.trim().isNotEmpty) 'note': _page.note.text.trim(),
      };
      if (code == 'CHEQUE') {
        final sid = _page.sayad.text.trim().toEnglishDigit();
        if (_page.bank.text.trim().isEmpty ||
            _page.bank.text.trim().length > 100 ||
            _page.number.text.trim().isEmpty ||
            _page.number.text.trim().length > 64 ||
            _page.due.text.isEmpty ||
            sid.isNotEmpty && !RegExp(r'^\d{16}$').hasMatch(sid) ||
            _page.drawer.text.trim().length > 200) {
          throw const FormatException('Invalid expense cheque');
        }
        input['cheque'] = {
          'bankName': _page.bank.text.trim(),
          'number': _page.number.text.trim().toEnglishDigit(),
          'dueAt': DateTime.parse(DateConvertor.jalaliToGrigori(_page.due.text))
              .toUtc()
              .toIso8601String(),
          if (sid.isNotEmpty) 'sayadId': sid,
          if (_page.drawer.text.trim().isNotEmpty)
            'drawerName': _page.drawer.text.trim(),
        };
      }
      attempted = true;
      {
        _page.saving = true;
        _page.update();
      }
      await widget.fx.authorize();
      final available = await widget.fx.targets(code);
      if (!available.any((r) => r.id == _page.target!.id)) {
        throw const FormatException('Fund no longer available');
      }
      final before = _page.expense!;
      await widget.fx.send(
        ExpenseCommand(
          'payment',
          {
            'expenseId': before.id,
            'expectedRevision': before.revision,
            'payment': input,
          },
          before: {'expense': before.json},
        ),
      );
      if (mounted) {
        Alert.success(
          code == 'CHEQUE'
              ? 'چک هزینه ثبت شد؛ تا تعیین نتیجه در انتظار است.'
              : 'پرداخت هزینه با موفقیت ثبت شد.',
        );
        _page.amount.clear();
        _page.note.clear();
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(
          failure is FormatException
              ? 'مبلغ مثبت تا مانده هزینه، منبع پرداخت و اطلاعات چک را بررسی کنید.'
              : ExpensesFX.message(failure),
          context: context,
        );
      }
    } finally {
      if (mounted) {
        {
          _page.saving = false;
          _page.update();
        }
        if (attempted) await load();
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_ExpensePaymentScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: 'پرداخت‌ها و چک‌های هزینه'),
        child: (_) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            MiniBTN(
              name: 'دریافت مجدد پرداخت‌ها',
              noFlex: true,
              icon: IconsaxPlusLinear.refresh,
              onTap: _page.loading || _page.saving ? null : load,
            ),
            if (_page.expense != null) ...[
              MyDivider(text: _page.expense!.json['title'] as String),
              Text('پرداخت‌شده: ${_money(_page.expense!.money('paidAmount'))}'),
              Text(
                'چک در انتظار: ${_money(_page.expense!.money('pendingAmount'))}',
              ),
              Text('مانده بدون پوشش: ${_money(_page.expense!.remaining)}'),
              for (final row in _page.payments) ...[
                ListTile(
                  key: ValueKey('disbursement-${row.id}'),
                  title: Text(
                    '${_money(row.json['amount'] as int)} — ${_methods.entries.where((e) => e.value == row.method).firstOrNull?.key ?? (row.method == 'WITHHELD' ? 'کسر از تسویه' : row.method)}',
                  ),
                  subtitle: Text(
                    '${_states[row.status]} — ${RemoteJson(row.json['routing']).optionalText('fundName') ?? 'شناسه منبع: ${RemoteJson(row.json['routing']).text('fundId')}'}',
                  ),
                  onTap:
                      _page.loading || _page.saving || widget.fx.pending != null
                      ? null
                      : () async {
                          await Get.toNamed(
                            nav_routes.RoutesName.EXPENSE_PAYMENT_ACTION,
                            arguments: {
                              'fx': widget.fx,
                              'expenseId': _page.expense!.id,
                              'id': row.id,
                            },
                            preventDuplicates: false,
                          );
                          if (mounted) await load();
                        },
                ),
                MyDivider(),
              ],
            ],
            if (widget.fx.pending != null)
              const Text(
                'درخواست قبلی تعیین تکلیف نشده است؛ از صفحه اصلی هزینه‌ها آن را پیگیری کنید.',
              ),
            if (canPay && widget.fx.pending == null) ...[
              MyDivider(text: 'پرداخت جدید'),
              MyTab(
                tab: _methods.keys
                    .where(
                      (k) =>
                          k != 'چک' ||
                          widget.fx.has('accounting.expense.cheque.pay'),
                    )
                    .toList(),
                value: _page.method,
                enabledValues: _page.loading || _page.saving
                    ? <String>{}
                    : null,
                callback: select,
              ),
              Input(
                key: const ValueKey('expense-payment-amount'),
                controller: _page.amount,
                name: 'مبلغ پرداخت (تومان)',
                require: true,
                keyboardType: TextInputType.number,
                readOnly: _page.loading || _page.saving,
                onChanged: (_) => _page.confirmed.value = 'بله',
              ),
              MyDivider(text: 'منبع پرداخت'),
              for (final row in _page.targets)
                MiniBTN(
                  name: '${_page.target?.id == row.id ? '✓ ' : ''}${row.name}',
                  noFlex: true,
                  icon: IconsaxPlusLinear.wallet,
                  onTap: _page.loading || _page.saving
                      ? null
                      : () {
                          _page.target = row;
                          _page.confirmed.value = 'بله';
                          _page.update();
                        },
                ),
              if (code == 'CHEQUE') ...[
                Input(
                  key: const ValueKey('expense-cheque-bank'),
                  controller: _page.bank,
                  onChanged: (_) => _page.confirmed.value = 'بله',
                  name: 'نام بانک روی چک',
                  maxLength: 100,
                  require: true,
                  readOnly: _page.loading || _page.saving,
                ),
                Input(
                  key: const ValueKey('expense-cheque-number'),
                  controller: _page.number,
                  onChanged: (_) => _page.confirmed.value = 'بله',
                  name: 'شماره چک',
                  maxLength: 64,
                  require: true,
                  readOnly: _page.loading || _page.saving,
                ),
                Input(
                  controller: _page.sayad,
                  onChanged: (_) => _page.confirmed.value = 'بله',
                  name: 'شناسه صیاد (اختیاری)',
                  maxLength: 16,
                  readOnly: _page.loading || _page.saving,
                ),
                Input(
                  controller: _page.drawer,
                  onChanged: (_) => _page.confirmed.value = 'بله',
                  name: 'نام صادرکننده (اختیاری)',
                  maxLength: 200,
                  readOnly: _page.loading || _page.saving,
                ),
                DateInput(
                  key: const ValueKey('expense-cheque-due'),
                  controller: _page.due,
                  name: 'سررسید چک',
                  require: true,
                  timePicker: true,
                  enabled: !_page.loading && !_page.saving,
                  onChanged: (_) => _page.confirmed.value = 'بله',
                ),
              ],
              Input(
                controller: _page.note,
                name: 'یادداشت پرداخت',
                maxLength: 1000,
                readOnly: _page.loading || _page.saving,
              ),
              BTN(
                name: 'ثبت پرداخت هزینه',
                disabled: _page.loading || _page.saving,
                onTap: submit,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ExpensePaymentAction extends StatefulWidget {
  final ExpensesFX fx;
  final String expenseId, id;
  const _ExpensePaymentAction({
    required this.fx,
    required this.expenseId,
    required this.id,
  });
  @override
  State<_ExpensePaymentAction> createState() => _ExpensePaymentActionState();
}

class _ExpensePaymentActionController extends GetxController {
  RemoteExpense? expense;
  ExpenseDisbursement? payment;
  bool loading = true, saving = false;
  final reason = TextEditingController(),
      confirmed = 'خیر'.obs,
      outcome = 'وصول‌شده'.obs;
}

class _ExpensePaymentActionState extends State<_ExpensePaymentAction> {
  late final _page = _ExpensePaymentActionController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    _page.reason.dispose();
    super.dispose();
  }

  bool get cheque =>
      _page.payment?.method == 'CHEQUE' && _page.payment?.status == 'PENDING';
  bool get allowed =>
      _page.expense != null &&
      _page.payment != null &&
      widget.fx.own(_page.expense!, 'payment') &&
      (cheque
          ? widget.fx.can('cheque') && widget.fx.can('payment')
          : _page.payment!.status == 'CONFIRMED' &&
                _page.payment!.method != 'WITHHELD' &&
                widget.fx.can('reverse'));
  Future<Object> load() async {
    {
      _page.loading = true;
      _page.expense = null;
      _page.payment = null;
      _page.confirmed.value = 'خیر';
      _page.update();
    }
    try {
      final row = await widget.fx.get(widget.expenseId);
      final rows = await widget.fx.payments(row);
      final matched = rows.where((r) => r.id == widget.id);
      if (matched.length != 1) throw const FormatException('Payment not found');
      if (mounted) {
        {
          _page.expense = row;
          _page.payment = matched.single;
          _page.update();
        }
      }
    } catch (failure) {
      if (mounted) Alert.error(ExpensesFX.message(failure), context: context);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  Future<void> submit() async {
    if (_page.loading || _page.saving || !allowed || widget.fx.pending != null)
      return;
    if (_page.reason.text.trim().isEmpty ||
        _page.reason.text.trim().length > 500 ||
        _page.confirmed.value != 'بله') {
      Alert.error(
        'دلیل و تأیید نتیجه واقعی یا برگشت کامل وجه لازم است.',
        context: context,
      );
      return;
    }
    {
      _page.saving = true;
      _page.update();
    }
    try {
      final row = _page.payment!, before = _page.expense!;
      await widget.fx.send(
        ExpenseCommand(
          cheque ? 'cheque' : 'reverse',
          {
            'disbursementId': row.id,
            'expectedRevision': row.json['revision'],
            'reason': _page.reason.text.trim(),
            if (cheque) ...{
              'status': const {
                'وصول‌شده': 'CONFIRMED',
                'برگشتی': 'BOUNCED',
                'عودت‌شده': 'RETURNED',
              }[_page.outcome.value],
              'confirmed': true,
            } else
              'fundsConfirmed': true,
          },
          before: {'expense': before.json, 'payment': row.json},
        ),
      );
      if (mounted) {
        Alert.success(
          cheque
              ? 'نتیجه چک هزینه با موفقیت ثبت شد.'
              : 'برگشت کامل پرداخت هزینه با موفقیت ثبت شد.',
        );
        Get.back();
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(ExpensesFX.message(failure), context: context);
        if (widget.fx.pending != null) Get.back();
      }
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_ExpensePaymentActionController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: 'جزئیات پرداخت هزینه'),
        child: (_) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            MiniBTN(
              name: 'دریافت مجدد',
              noFlex: true,
              icon: IconsaxPlusLinear.refresh,
              onTap: _page.loading || _page.saving ? null : load,
            ),
            if (_page.payment != null) ...[
              Text('مبلغ: ${_money(_page.payment!.json['amount'] as int)}'),
              Text('وضعیت: ${_states[_page.payment!.status]}'),
              Text(
                'منبع: ${RemoteJson(_page.payment!.json['routing']).optionalText('fundName') ?? RemoteJson(_page.payment!.json['routing']).text('fundId')}',
              ),
              if (_page.payment!.method == 'CHEQUE') ...[
                Text(
                  'بانک: ${RemoteJson(_page.payment!.json['cheque']).text('bankName')}',
                ),
                Text(
                  'شماره: ${RemoteJson(_page.payment!.json['cheque']).text('number')}',
                ),
                Text(
                  'سررسید: ${DateConvertor.grigoriToJalali(DateTime.parse(RemoteJson(_page.payment!.json['cheque']).text('dueAt')))}',
                ),
              ],
              if (allowed) ...[
                MyDivider(text: cheque ? 'نتیجه واقعی چک' : 'برگشت کامل وجه'),
                if (cheque)
                  MyTab(
                    tab: const ['وصول‌شده', 'برگشتی', 'عودت‌شده'],
                    value: _page.outcome,
                    enabledValues: _page.loading || _page.saving
                        ? <String>{}
                        : null,
                    callback: (String v) {
                      _page.outcome.value = v;
                      _page.confirmed.value = 'خیر';
                    },
                  ),
                Input(
                  key: const ValueKey('expense-payment-action-reason'),
                  controller: _page.reason,
                  name: 'دلیل',
                  require: true,
                  maxLength: 500,
                  readOnly: _page.loading || _page.saving,
                ),
                Text(
                  cheque ? 'نتیجه انتخاب‌شده مطابق نتیجه واقعی چک است؟' : 'تمام مبلغ واقعاً به همان منبع اصلی برگشته است؟ منبع پرداخت قابل جایگزینی نیست.',
                ),
                MyTab(
                  tab: const ['خیر', 'بله'],
                  value: _page.confirmed,
                  enabledValues: _page.loading || _page.saving
                      ? <String>{}
                      : null,
                  callback: (String v) => _page.confirmed.value = v,
                ),
                BTN(
                  name: cheque ? 'ثبت نتیجه چک هزینه' : 'ثبت برگشت کامل پرداخت',
                  disabled:
                      _page.loading ||
                      _page.saving ||
                      widget.fx.pending != null,
                  onTap: submit,
                ),
              ] else
                const Text(
                  'این پرداخت در وضعیت فعلی یا با مجوز فعلی قابل تغییر نیست.',
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget buildExpensePaymentActionRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _ExpensePaymentAction(
    fx: args.required<ExpensesFX>('fx'),
    expenseId: args.required<String>('expenseId'),
    id: args.required<String>('id'),
  );
}

Widget buildExpensePaymentRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ExpensePaymentScreen(
    fx: args.required<ExpensesFX>('fx'),
    expense: args.required<RemoteExpense>('expense'),
  );
}
