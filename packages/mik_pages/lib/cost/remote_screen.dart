import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/expense.dart';
import 'package:mik_data/source/remote/models/remote_json.dart';
import 'package:mik_data/source/remote/models/supplier.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/expenses.dart';
import 'package:mik_data/utils/fx/suppliers.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

String expenseMoney(int amount) => '${amount.toString().seRagham()} تومان';
const expensePaymentStates = {
  'UNPAID': 'پرداخت‌نشده',
  'PARTIALLY_PAID': 'پرداخت جزئی',
  'PAID': 'تسویه‌شده',
};

class RemoteExpensesScreen extends StatefulWidget {
  final String appId;
  const RemoteExpensesScreen({required this.appId, super.key});
  @override
  State<RemoteExpensesScreen> createState() => _RemoteExpensesScreenState();
}

class _RemoteExpensesScreenController extends GetxController {
  RealtimeWatch? _realtime;
  int _readGeneration = 0;
  ExpensesFX? fx;
  int tab = 0;
  bool loading = true, saving = false, opening = false;
  String? error;
  List<RemoteExpense> expenses = [];
  List<ExpenseCategory> categories = [];
}

class _RemoteExpensesScreenState extends State<RemoteExpensesScreen> {
  late final _page = _RemoteExpensesScreenController();

  @override
  void dispose() {
    _page._realtime?.dispose();
    _page._readGeneration++;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final realtimeContext = BusinessContext.forApp(widget.appId);
    if (realtimeContext != null) {
      _page._realtime = RealtimeWatch(
        RealtimeFX.forContext(realtimeContext),
        {
          'accounting.expense',
          'accounting.category',
          'accounting.disbursement',
          'accounting.expense-cheque-followup',
          'accounting.payee',
        },
        () async {
          await load(background: true);
        },
        busy: () => _page.loading || _page.saving || _page.opening,
        invalidate: () {
          if (mounted) {
            {
              _page._readGeneration++;
              _page.loading = false;
              _page.expenses = [];
              _page.categories = [];
              _page.update();
            }
          }
        },
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  Future<Object> load({bool background = false}) async {
    if (!mounted || _page.saving) return '';
    final request = ++_page._readGeneration;
    {
      if (!background) _page.loading = true;
      _page.error = null;
      if (!background) _page.expenses = [];
      if (!background) _page.categories = [];
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= ExpensesFX(active);
      await _page.fx!.authorize();
      await _page.fx!.restore();
      final loadedExpenses = _page.tab == 0
          ? await _page.fx!.all()
          : <RemoteExpense>[];
      final loadedCategories = _page.tab == 2
          ? await _page.fx!.categories()
          : <ExpenseCategory>[];
      if (mounted && request == _page._readGeneration) {
        _page.expenses = loadedExpenses;
        _page.categories = loadedCategories;
      }
    } catch (failure) {
      if (mounted && request == _page._readGeneration) {
        _page.error = ExpensesFX.message(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted && request == _page._readGeneration) {
        {
          _page.loading = false;
          _page.update();
        }
      }
    }
    return '';
  }

  Future<void> form({RemoteExpense? item, ExpenseCategory? category}) async {
    if (_page.loading || _page.saving || _page.fx?.pending != null) return;
    _page.opening = true;
    try {
      await (_page.tab == 2
          ? Get.toNamed(
              nav_routes.RoutesName.EXPENSE_CATEGORY_FORM,
              arguments: {'fx': _page.fx!, 'item': category},
              preventDuplicates: false,
            )
          : Get.toNamed(
              nav_routes.RoutesName.REMOTE_EXPENSE_FORM,
              arguments: {'appId': widget.appId, 'fx': _page.fx, 'item': item},
              preventDuplicates: false,
            ));
    } finally {
      _page.opening = false;
    }
    if (mounted) await load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_RemoteExpensesScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => '',
      header: Header.page(
        context,
        text: 'هزینه‌ها',
        isBack: widget.appId == 'mik',
      ),
      floatingActionButton:
          _page.fx != null &&
              !_page.loading &&
              !_page.saving &&
              _page.fx!.pending == null &&
              (_page.tab == 0 && _page.fx!.can('create') ||
                  _page.tab == 2 && _page.fx!.can('category-create'))
          ? MyFAB(
              text: _page.tab == 2 ? 'دسته‌بندی جدید' : 'هزینه جدید',
              icon: IconsaxPlusLinear.add,
              onTap: form,
            )
          : const SizedBox.shrink(),
      child: (_) => Column(
        children: [
          MyTabBar(
            tabs: const ['هزینه‌ها', 'ارسال محصولات', 'دسته‌بندی‌ها'],
            currentIndex: _page.tab,
            divider: false,
            index: (i) {
              if (!_page.loading && !_page.saving) {
                _page.tab = i as int;
                load();
              }
            },
          ),
          if (_page.loading || _page.saving) const LinearProgressIndicator(),
          if (_page.error != null)
            Text(_page.error!, textAlign: TextAlign.center),
          MiniBTN(
            name: 'دریافت مجدد',
            noFlex: true,
            icon: IconsaxPlusLinear.refresh,
            onTap: _page.loading || _page.saving ? null : load,
          ),
          if (_page.fx?.pending != null) ...[
            Text(
              'درخواست قبلی تعیین تکلیف نشده است: ${_page.fx!.pending!.body['title'] ?? _page.fx!.pending!.body['name'] ?? _page.fx!.pending!.action}',
            ),
            BTN(
              name: 'پیگیری درخواست هزینه',
              disabled: _page.saving || _page.loading,
              onTap: () async {
                {
                  _page.saving = true;
                  _page.update();
                }
                try {
                  await _page.fx!.send(_page.fx!.pending!);
                  if (mounted)
                    Alert.success('درخواست هزینه با موفقیت تأیید شد.');
                } catch (failure) {
                  if (context.mounted) {
                    Alert.error(ExpensesFX.message(failure), context: context);
                  }
                } finally {
                  if (mounted) {
                    {
                      _page.saving = false;
                      _page.update();
                    }
                    await load();
                  }
                }
              },
            ),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 75),
              children: [
                if (_page.tab == 1)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'هزینه ارسالِ فاکتور را در جزئیات همان فاکتور ببینید. برای ثبت یک هزینه مستقل حمل‌ونقل، از تب هزینه‌ها استفاده کنید.',
                    ),
                  ),
                if (_page.tab == 0) ...[
                  if (!_page.loading &&
                      _page.expenses.isEmpty &&
                      _page.error == null)
                    const Center(
                      child: Text('هزینه‌ای برای نمایش وجود ندارد.'),
                    ),
                  for (final row in _page.expenses) ...[
                    ListTile(
                      key: ValueKey('expense-${row.id}'),
                      title: Text(row.json['title'] as String),
                      subtitle: Text(
                        '${RemoteJson(row.json['payeeSnapshot']).text('name')} — ${expensePaymentStates[row.json['paymentStatus']]}${row.status == 'VOIDED' ? ' — لغوشده' : ''}\n${expenseMoney(row.money('amount'))}',
                      ),
                      onTap:
                          _page.loading ||
                              _page.saving ||
                              _page.fx!.pending != null
                          ? null
                          : () async {
                              await Get.toNamed(
                                nav_routes.RoutesName.EXPENSE_DETAIL,
                                arguments: {'fx': _page.fx!, 'id': row.id},
                                preventDuplicates: false,
                              );
                              if (mounted) await load();
                            },
                    ),
                    MyDivider(),
                  ],
                ],
                if (_page.tab == 2)
                  for (final row in _page.categories) ...[
                    ListTile(
                      title: Text(row.name),
                      subtitle: Text(row.status == 'ACTIVE' ? 'فعال' : 'آرشیو'),
                      onTap:
                          _page.fx!.can('category-update') &&
                              _page.fx!.pending == null
                          ? () => form(category: row)
                          : null,
                    ),
                    MyDivider(),
                  ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ExpenseDetailScreen extends StatefulWidget {
  final ExpensesFX fx;
  final String id;
  const ExpenseDetailScreen({required this.fx, required this.id, super.key});
  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenController extends GetxController {
  RealtimeWatch? _realtime;
  int _readGeneration = 0;
  RemoteExpense? row;
  bool loading = true;
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late final _page = _ExpenseDetailScreenController();

  @override
  void dispose() {
    _page._realtime?.dispose();
    _page._readGeneration++;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final realtimeContext = widget.fx.context;
    _page._realtime = RealtimeWatch(
      RealtimeFX.forContext(realtimeContext),
      {
        'accounting.expense',
        'accounting.disbursement',
        'accounting.expense-cheque-followup',
      },
      () async {
        await load(background: true);
      },
      busy: () => _page.loading,
      invalidate: () {
        if (mounted) {
          {
            _page._readGeneration++;
            _page.loading = false;
            _page.row = null;
            _page.update();
          }
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  Future<Object> load({bool background = false}) async {
    if (!mounted) return '';
    final request = ++_page._readGeneration;
    {
      if (!background) _page.loading = true;
      if (!background) _page.row = null;
      _page.update();
    }
    try {
      final result = await widget.fx.get(widget.id);
      if (mounted && request == _page._readGeneration) {
        _page.row = result;
        _page.update();
      }
    } catch (failure) {
      if (mounted && request == _page._readGeneration) {
        Alert.error(ExpensesFX.message(failure), context: context);
      }
    } finally {
      if (mounted && request == _page._readGeneration) {
        {
          _page.loading = false;
          _page.update();
        }
      }
    }
    return '';
  }

  Future<void> cancel() async {
    await MyBottomSheet.view(
      context,
      title: _page.row!.json['title'] as String,
      child: (_) => _ExpenseCancelForm(fx: widget.fx, expense: _page.row!),
    );
    if (mounted) await load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_ExpenseDetailScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => '',
      header: Header.page(context, text: 'جزئیات هزینه'),
      child: (_) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: [
          if (_page.loading) const LinearProgressIndicator(),
          MiniBTN(
            name: 'دریافت مجدد',
            icon: IconsaxPlusLinear.refresh,
            noFlex: true,
            onTap: _page.loading ? null : load,
          ),
          if (_page.row != null) ...[
            MyDivider(text: _page.row!.json['title'] as String),
            Text(
              'سرویس‌دهنده: ${RemoteJson(_page.row!.json['payeeSnapshot']).text('name')}',
            ),
            Text(
              'دسته‌بندی: ${RemoteJson(_page.row!.json['categorySnapshot']).text('name')}',
            ),
            Text('مبلغ: ${expenseMoney(_page.row!.money('amount'))}'),
            Text('پرداخت‌شده: ${expenseMoney(_page.row!.money('paidAmount'))}'),
            Text(
              'چک در انتظار: ${expenseMoney(_page.row!.money('pendingAmount'))}',
            ),
            Text('مانده بدون پوشش: ${expenseMoney(_page.row!.remaining)}'),
            Text(
              'وضعیت: ${_page.row!.status == 'ISSUED' ? 'ثبت‌شده' : 'لغوشده'}',
            ),
            Text(
              'تاریخ وقوع: ${DateConvertor.grigoriToJalali(DateTime.parse(_page.row!.json['occurredAt'] as String))}',
            ),
            if (_page.row!.json['dueAt'] != null)
              Text(
                'سررسید: ${DateConvertor.grigoriToJalali(DateTime.parse(_page.row!.json['dueAt'] as String))}',
              ),
            if (_page.row!.json['note'] != null)
              Text(_page.row!.json['note'] as String),
            BTN(
              name: 'پرداخت‌ها و چک‌های هزینه',
              navigate: true,
              disabled: _page.loading || widget.fx.pending != null,
              onTap: () async {
                await Get.toNamed(
                  nav_routes.RoutesName.EXPENSE_PAYMENT,
                  arguments: {'fx': widget.fx, 'expense': _page.row!},
                  preventDuplicates: false,
                );
                if (mounted) await load();
              },
            ),
            if (_page.row!.status == 'ISSUED' &&
                widget.fx.can('amend') &&
                widget.fx.own(_page.row!, 'amend'))
              BTN(
                name: 'ویرایش هزینه',
                navigate: true,
                disabled: _page.loading || widget.fx.pending != null,
                onTap: () async {
                  await Get.toNamed(
                    nav_routes.RoutesName.REMOTE_EXPENSE_FORM,
                    arguments: {
                      'appId': widget.fx.context.auth.appId,
                      'fx': widget.fx,
                      'item': _page.row,
                    },
                    preventDuplicates: false,
                  );
                  if (mounted) await load();
                },
              ),
            if (_page.row!.status == 'ISSUED' &&
                _page.row!.money('paidAmount') == 0 &&
                _page.row!.money('pendingAmount') == 0 &&
                widget.fx.can('cancel') &&
                widget.fx.own(_page.row!, 'cancel'))
              BTN(
                name: 'لغو هزینه',
                type: BTNType.cancel,
                disabled: _page.loading || widget.fx.pending != null,
                onTap: cancel,
              ),
          ],
        ],
      ),
    ),
  );
}

class _ExpenseCancelForm extends StatefulWidget {
  final ExpensesFX fx;
  final RemoteExpense expense;
  const _ExpenseCancelForm({required this.fx, required this.expense});
  @override
  State<_ExpenseCancelForm> createState() => _ExpenseCancelFormState();
}

class _ExpenseCancelFormController extends GetxController {
  final reason = TextEditingController();
  bool saving = false;
}

class _ExpenseCancelFormState extends State<_ExpenseCancelForm> {
  late final _page = _ExpenseCancelFormController();

  @override
  void dispose() {
    _page.reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      GetBuilder<_ExpenseCancelFormController>(
        init: _page,
        global: false,
        dispose: (state) => state.controller?.onDelete(),
        builder: (_) => PopScope(
          canPop: !_page.saving,
          child: Column(
            children: [
              Input(
                controller: _page.reason,
                name: 'دلیل لغو هزینه',
                require: true,
                maxLength: 500,
                readOnly: _page.saving,
              ),
              BTN(
                name: 'لغو هزینه',
                type: BTNType.cancel,
                disabled: _page.saving || widget.fx.pending != null,
                onTap: () async {
                  if (_page.reason.text.trim().isEmpty) {
                    Alert.error('دلیل لغو را وارد کنید.', context: context);
                    return;
                  }
                  {
                    _page.saving = true;
                    _page.update();
                  }
                  try {
                    await widget.fx.send(
                      ExpenseCommand(
                        'cancel',
                        {
                          'expenseId': widget.expense.id,
                          'expectedRevision': widget.expense.revision,
                          'reason': _page.reason.text.trim(),
                        },
                        before: {'expense': widget.expense.json},
                      ),
                    );
                    if (context.mounted) {
                      Alert.success('هزینه با موفقیت لغو شد.');
                      Get.back();
                    }
                  } catch (failure) {
                    if (context.mounted) {
                      Alert.error(
                        ExpensesFX.message(failure),
                        context: context,
                      );
                      if (widget.fx.pending != null) Get.back();
                    }
                  } finally {
                    if (mounted) {
                      _page.saving = false;
                      _page.update();
                    }
                  }
                },
              ),
            ],
          ),
        ),
      );
}

class RemoteExpenseForm extends StatefulWidget {
  final String appId;
  final ExpensesFX? fx;
  final RemoteExpense? item;
  const RemoteExpenseForm({required this.appId, this.fx, this.item, super.key});
  @override
  State<RemoteExpenseForm> createState() => _RemoteExpenseFormState();
}

class _RemoteExpenseFormController extends GetxController {
  ExpensesFX? fx;
  bool loading = true, saving = false;
  final title = TextEditingController(),
      amount = TextEditingController(),
      note = TextEditingController(),
      occurred = TextEditingController(),
      due = TextEditingController(),
      reason = TextEditingController();
  List<ExpenseCategory> categories = [];
  List<RemoteSupplier> payees = [];
  String? categoryId, payeeId;
}

class _RemoteExpenseFormState extends State<RemoteExpenseForm> {
  late final _page = _RemoteExpenseFormController();

  @override
  void initState() {
    super.initState();
    final row = widget.item;
    if (row != null) {
      _page.title.text = row.json['title'] as String;
      _page.amount.text = '${row.money('amount')}';
      _page.note.text = row.json['note'] as String? ?? '';
      _page.categoryId = row.json['categoryId'] as String;
      _page.payeeId = row.json['payeeId'] as String;
      if (row.json['dueAt'] != null) {
        _page.due.text = DateConvertor.grigoriToJalali(
          DateTime.parse(row.json['dueAt'] as String),
        );
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _page.title,
      _page.amount,
      _page.note,
      _page.occurred,
      _page.due,
      _page.reason,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Object> load() async {
    {
      _page.loading = true;
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= widget.fx ?? ExpensesFX(active);
      await _page.fx!.authorize();
      await _page.fx!.restore();
      _page.categories = (await _page.fx!.categories())
          .where((r) => r.status == 'ACTIVE')
          .toList();
      final suppliers = SuppliersFX.forContext(
        active,
        type: AccountingPersonType.serviceProvider,
      );
      await suppliers.authorize();
      _page.payees = await suppliers.all();
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

  String? date(TextEditingController c) => c.text.isEmpty
      ? null
      : DateTime.parse(DateConvertor.jalaliToGrigori(c.text))
            .toUtc()
            .toIso8601String();
  Future<void> submit() async {
    if (_page.loading || _page.saving || _page.fx == null) return;
    try {
      final value = int.tryParse(
        _page.amount.text.toEnglishDigit().replaceAll(',', '').trim(),
      );
      if (value == null ||
          value <= 0 ||
          value > 9007199254740991 ||
          _page.title.text.trim().isEmpty ||
          _page.title.text.trim().length > 200 ||
          !_page.categories.any((r) => r.id == _page.categoryId) ||
          !_page.payees.any((r) => r.id == _page.payeeId) ||
          _page.note.text.trim().length > 1000) {
        throw const FormatException('Invalid expense');
      }
      final before = widget.item,
          body = <String, dynamic>{
            'title': _page.title.text.trim(),
            'amount': value,
            'categoryId': _page.categoryId,
            'payeeId': _page.payeeId,
          };
      if (before != null) {
        if (_page.reason.text.trim().isEmpty ||
            _page.reason.text.trim().length > 500 ||
            before.json['note'] != null && _page.note.text.trim().isEmpty) {
          throw const FormatException('Reason and note required');
        }
        body.addAll({
          'expenseId': before.id,
          'expectedRevision': before.revision,
          'reason': _page.reason.text.trim(),
        });
        if (_page.due.text.isEmpty) {
          body['dueAt'] = null;
        } else if (before.json['dueAt'] == null ||
            _page.due.text !=
                DateConvertor.grigoriToJalali(
                  DateTime.parse(before.json['dueAt'] as String),
                )) {
          body['dueAt'] = date(_page.due);
        }
      } else {
        if (_page.occurred.text.isNotEmpty) {
          final time = date(_page.occurred)!;
          if (DateTime.parse(time).isAfter(DateTime.now())) {
            throw const FormatException('Future expense');
          }
          body['occurredAt'] = time;
        }
        if (_page.due.text.isNotEmpty) body['dueAt'] = date(_page.due);
      }
      if (_page.note.text.trim().isNotEmpty)
        body['note'] = _page.note.text.trim();
      {
        _page.saving = true;
        _page.update();
      }
      await _page.fx!.send(
        ExpenseCommand(
          before == null ? 'create' : 'amend',
          body,
          before: before == null ? null : {'expense': before.json},
        ),
      );
      if (mounted) {
        Alert.success(
          before == null
              ? 'هزینه با موفقیت ثبت شد؛ پرداخت جداگانه ثبت می‌شود.'
              : 'هزینه با موفقیت ویرایش شد.',
        );
        Get.back();
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(
          failure is FormatException
              ? 'عنوان، مبلغ صحیح به تومان، سرویس‌دهنده، دسته‌بندی، تاریخ و دلیل را بررسی کنید؛ یادداشت قبلی با متن خالی قابل حذف نیست.'
              : ExpensesFX.message(failure),
          context: context,
        );
        if (_page.fx?.pending != null) Get.back();
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
  ) => GetBuilder<_RemoteExpenseFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(
          context,
          text: widget.item == null ? 'هزینه جدید' : 'ویرایش هزینه',
        ),
        child: (_) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            Input(
              key: const ValueKey('expense-title'),
              controller: _page.title,
              name: 'عنوان هزینه',
              require: true,
              maxLength: 200,
              readOnly: _page.loading || _page.saving,
            ),
            Input(
              key: const ValueKey('expense-amount'),
              controller: _page.amount,
              name: 'مبلغ (تومان)',
              require: true,
              keyboardType: TextInputType.number,
              readOnly: _page.loading || _page.saving,
            ),
            MyDivider(text: 'دسته‌بندی'),
            for (final row in _page.categories)
              MiniBTN(
                name: '${_page.categoryId == row.id ? '✓ ' : ''}${row.name}',
                noFlex: true,
                icon: IconsaxPlusLinear.category,
                onTap: _page.loading || _page.saving
                    ? null
                    : () {
                        _page.categoryId = row.id;
                        _page.update();
                      },
              ),
            if (_page.fx?.can('category-create') == true)
              BTN(
                name: 'تعریف دسته‌بندی',
                navigate: true,
                disabled: _page.loading || _page.saving,
                onTap: () async {
                  await Get.toNamed(
                    nav_routes.RoutesName.EXPENSE_CATEGORY_FORM,
                    arguments: {'fx': _page.fx!},
                    preventDuplicates: false,
                  );
                  if (mounted) await load();
                },
              ),
            MyDivider(text: 'سرویس‌دهنده دریافت‌کننده هزینه'),
            for (final row in _page.payees)
              MiniBTN(
                name: '${_page.payeeId == row.id ? '✓ ' : ''}${row.name}',
                noFlex: true,
                icon: IconsaxPlusLinear.user,
                onTap: _page.loading || _page.saving
                    ? null
                    : () {
                        _page.payeeId = row.id;
                        _page.update();
                      },
              ),
            BTN(
              name: 'تعریف یا بررسی سرویس‌دهندگان',
              navigate: true,
              disabled: _page.loading || _page.saving,
              onTap: () async {
                await Get.toNamed(
                  nav_routes.RoutesName.SUPPLIERS,
                  arguments: {
                    'appId': widget.appId,
                    'type': AccountingPersonType.serviceProvider,
                  },
                  preventDuplicates: false,
                );
                if (mounted) await load();
              },
            ),
            if (widget.item == null)
              DateInput(
                controller: _page.occurred,
                name: 'تاریخ وقوع (اختیاری؛ پیش‌فرض زمان سرور)',
                timePicker: true,
                enabled: !_page.loading && !_page.saving,
                onChanged: (_) {
                  _page.update();
                },
              ),
            DateInput(
              controller: _page.due,
              name: 'سررسید (اختیاری)',
              timePicker: true,
              enabled: !_page.loading && !_page.saving,
              onChanged: (_) {
                _page.update();
              },
            ),
            MiniBTN(
              name: 'بدون سررسید',
              noFlex: true,
              icon: IconsaxPlusLinear.close_circle,
              onTap: _page.loading || _page.saving
                  ? null
                  : () {
                      _page.due.clear();
                      _page.update();
                    },
            ),
            Input(
              controller: _page.note,
              name: 'یادداشت',
              maxLength: 1000,
              readOnly: _page.loading || _page.saving,
            ),
            if (widget.item != null)
              Input(
                controller: _page.reason,
                name: 'دلیل ویرایش',
                maxLength: 500,
                require: true,
                readOnly: _page.loading || _page.saving,
              ),
            const Text(
              'ثبت هزینه به‌تنهایی وجهی جابه‌جا نمی‌کند؛ پرداخت از جزئیات هزینه انجام می‌شود.',
            ),
            if (_page.fx?.pending != null)
              const Text(
                'درخواست قبلی تعیین تکلیف نشده؛ از صفحه هزینه‌ها آن را پیگیری کنید.',
              ),
            BTN(
              name: 'ثبت هزینه',
              disabled:
                  _page.loading || _page.saving || _page.fx?.pending != null,
              onTap: submit,
            ),
            MiniBTN(
              name: 'دریافت مجدد گزینه‌ها',
              noFlex: true,
              icon: IconsaxPlusLinear.refresh,
              onTap: _page.loading || _page.saving ? null : load,
            ),
          ],
        ),
      ),
    ),
  );
}

class ExpenseCategoryForm extends StatefulWidget {
  final ExpensesFX fx;
  final ExpenseCategory? item;
  const ExpenseCategoryForm({required this.fx, this.item, super.key});
  @override
  State<ExpenseCategoryForm> createState() => _ExpenseCategoryFormState();
}

class _ExpenseCategoryFormController extends GetxController {
  _ExpenseCategoryFormController(this.widget);
  ExpenseCategoryForm widget;
  late final name = TextEditingController(text: widget.item?.name ?? '');
  late final state = (widget.item?.status == 'ARCHIVED' ? 'آرشیو' : 'فعال').obs;
  bool saving = false;
}

class _ExpenseCategoryFormState extends State<ExpenseCategoryForm> {
  late final _page = _ExpenseCategoryFormController(widget);

  @override
  void dispose() {
    _page.name.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_ExpenseCategoryFormController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: 'دسته‌بندی هزینه'),
        child: (_) => ListView(
          children: [
            Input(
              key: const ValueKey('expense-category-name'),
              controller: _page.name,
              name: 'نام دسته‌بندی',
              maxLength: 200,
              require: true,
              readOnly: _page.saving,
            ),
            if (widget.item != null)
              MyTab(
                tab: const ['فعال', 'آرشیو'],
                value: _page.state,
                enabledValues: _page.saving ? <String>{} : null,
                callback: (String v) => _page.state.value = v,
              ),
            BTN(
              name: 'ثبت دسته‌بندی',
              disabled: _page.saving || widget.fx.pending != null,
              onTap: () async {
                if (_page.name.text.trim().isEmpty) {
                  Alert.error('نام دسته‌بندی را وارد کنید.', context: context);
                  return;
                }
                {
                  _page.saving = true;
                  _page.update();
                }
                try {
                  await widget.fx.send(
                    ExpenseCommand(
                      widget.item == null
                          ? 'category-create'
                          : 'category-update',
                      {
                        'name': _page.name.text.trim(),
                        if (widget.item != null) ...{
                          'categoryId': widget.item!.id,
                          'expectedRevision': widget.item!.json['revision'],
                          'status': _page.state.value == 'فعال'
                              ? 'ACTIVE'
                              : 'ARCHIVED',
                        },
                      },
                    ),
                  );
                  if (context.mounted) {
                    Alert.success('دسته‌بندی با موفقیت ثبت شد.');
                    Get.back();
                  }
                } catch (failure) {
                  if (context.mounted) {
                    Alert.error(ExpensesFX.message(failure), context: context);
                    if (widget.fx.pending != null) Get.back();
                  }
                } finally {
                  if (mounted) {
                    _page.saving = false;
                    _page.update();
                  }
                }
              },
            ),
          ],
        ),
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant ExpenseCategoryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

Widget buildExpenseCategoryFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ExpenseCategoryForm(
    fx: args.required<ExpensesFX>('fx'),
    item: args.optional<ExpenseCategory>('item'),
  );
}

Widget buildRemoteExpenseFormRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return RemoteExpenseForm(
    appId: args.required<String>('appId'),
    fx: args.optional<ExpensesFX>('fx'),
    item: args.optional<RemoteExpense>('item'),
  );
}

Widget buildExpenseDetailRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ExpenseDetailScreen(
    fx: args.required<ExpensesFX>('fx'),
    id: args.required<String>('id'),
  );
}
