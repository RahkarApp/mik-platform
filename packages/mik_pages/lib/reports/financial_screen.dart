import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:get/get.dart';
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/financial_report.dart';
import 'package:mik_data/source/remote/models/treasury.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/expenses.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import '../invoice/read_screen.dart' show viewReportedInvoice;
import 'components/reportBTN.dart';

String financialMoney(Object? value) {
  final amount = FinancialReportPage.money(value);
  // The existing digit separator treats the minus sign as a digit.
  return '${amount < 0 ? '-' : ''}${amount.abs().toString().seRagham()} تومان';
}

class FinancialReportEntries extends StatefulWidget {
  final String appId;
  const FinancialReportEntries({required this.appId, super.key});
  @override
  State<FinancialReportEntries> createState() => _FinancialReportEntriesState();
}

class _FinancialReportEntriesController extends GetxController {
  FinancialReportsFX? fx;
  bool loading = true;
  String? error;
}

class _FinancialReportEntriesState extends State<FinancialReportEntries> {
  late final _page = _FinancialReportEntriesController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  Future<void> load() async {
    {
      _page.loading = true;
      _page.error = null;
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= FinancialReportsFX(active);
      await _page.fx!.authorize();
    } catch (failure) {
      if (mounted) {
        _page.error = FinancialReportsFX.message(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_FinancialReportEntriesController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        if (_page.loading) return const LinearProgressIndicator();
        if (_page.error != null) {
          return Column(
            children: [
              Text(_page.error!),
              MiniBTN(
                icon: IconsaxPlusLinear.refresh,
                name: 'دریافت مجدد مجوز گزارش‌ها',
                noFlex: true,
                onTap: load,
              ),
            ],
          );
        }
        final available = financialReportNames.entries.where(
          (e) => _page.fx!.has(e.key) || _page.fx!.has(e.key, business: true),
        );
        return Column(
          children: [
            if (available.isEmpty)
              const Text('مجوز گزارش مالی در این شعبه یا کسب‌وکار ندارید.'),
            for (final entry in available)
              ReportBTNDashboard(
                name: entry.value,
                desc: 'گزارش مالی از اطلاعات ثبت‌شده سرور',
                icon: IconsaxPlusLinear.chart,
                onTap: () => Get.toNamed(
                  nav_routes.RoutesName.FINANCIAL_REPORT,
                  arguments: {'fx': _page.fx!, 'kind': entry.key},
                  preventDuplicates: false,
                ),
              ),
          ],
        );
      },
    );
  }
}

class FinancialReportScreen extends StatefulWidget {
  final FinancialReportsFX fx;
  final String kind;
  const FinancialReportScreen({
    required this.fx,
    required this.kind,
    super.key,
  });
  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenController extends GetxController {
  _FinancialReportScreenController(this.widget);
  FinancialReportScreen widget;
  late bool business =
      !widget.fx.has(widget.kind) && widget.fx.has(widget.kind, business: true);
  bool loading = false;
  RealtimeWatch? _realtime;
  int _readGeneration = 0;
  String? _loadedFilters;
  String section = 'OBLIGATIONS', groupBy = 'CATEGORY';
  String? error;
  TreasuryFund? fund;
  FinancialReportPage? report;
  final rows = <Map<String, dynamic>>[];
  final cursors = <String>{};
  late final start = TextEditingController(
    text: DateConvertor.jalali(
      date: DateTime.now().subtract(const Duration(days: 29)),
    ),
  );
  late final end = TextEditingController(text: DateConvertor.jalali());
  FinancialReportsFX get fx => widget.fx;
}

class _FinancialReportScreenState extends State<FinancialReportScreen> {
  late final _page = _FinancialReportScreenController(widget);

  String get _filters =>
      '${_page.business}|${_page.start.text}|${_page.end.text}|${_page.section}|${_page.groupBy}|${_page.fund?.id}';

  @override
  void initState() {
    super.initState();
    _page._realtime = RealtimeWatch(
      RealtimeFX.forContext(_page.fx.context),
      {
        'accounting.sale',
        'accounting.purchase',
        'accounting.payment',
        'accounting.cheque',
        'accounting.account',
        'accounting.entry',
        'accounting.source',
        'accounting.cash-fund',
        'accounting.bank-fund',
        'accounting.transfer',
        'accounting.card-settlement',
        'accounting.expense',
        'accounting.disbursement',
        'accounting.journal',
        'accounting.ledger',
        'accounting.loan',
        'accounting.loan-entry',
        'accounting.partner-movement',
        'accounting.fixed-asset',
        'accounting.asset-movement',
        'accounting.stock-cost',
        'inventory.valuation',
      },
      refreshFromServer,
      busy: () => _page.loading,
      invalidate: () {
        if (mounted) {
          {
            _page._readGeneration++;
            _page.loading = false;
            clear();
            _page.update();
          }
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.kind != 'treasury') load();
    });
  }

  @override
  void dispose() {
    _page._realtime?.dispose();
    _page._readGeneration++;
    _page.start.dispose();
    _page.end.dispose();
    super.dispose();
  }

  void clear() {
    _page.report = null;
    _page.rows.clear();
    _page.cursors.clear();
    _page.error = null;
  }

  DateTime day(String value) {
    if (value.isEmpty) throw const AuthError(400, 'REPORT_RANGE_INVALID');
    final parsed = DateTime.parse(DateConvertor.jalaliToGrigori(value));
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> refreshFromServer() async {
    // Unsubmitted date/fund filters belong to the user; do not apply them in the background.
    if (_page._loadedFilters == null || _page._loadedFilters != _filters)
      return;
    final count = _page.rows.length;
    await load(background: true);
    while (mounted &&
        _page.error == null &&
        _page.rows.length < count &&
        _page.report?.next != null) {
      await load(more: true, background: true);
    }
  }

  Future<void> load({bool more = false, bool background = false}) async {
    if (_page.loading) return;
    final request = ++_page._readGeneration;
    final requestedFilters = _filters;
    _page._loadedFilters ??= requestedFilters;
    final previous = _page.report;
    if (more && previous?.next == null) return;
    {
      if (!background) _page.loading = true;
      _page.error = null;
      if (!more && !background) clear();
      _page.update();
    }
    try {
      await _page.fx.authorize();
      if (widget.kind == 'treasury' && _page.fund == null) {
        throw const AuthError(400, 'REPORT_FUND_REQUIRED');
      }
      final page = await _page.fx.page(
        widget.kind,
        business: _page.business,
        startAt: widget.kind == 'balances' ? null : day(_page.start.text),
        // The picker includes the final local day; the API's endAt is exclusive.
        endAt: widget.kind == 'balances'
            ? null
            : day(_page.end.text).add(const Duration(days: 1)),
        section: _page.section,
        groupBy: _page.groupBy,
        fundId: _page.fund?.id,
        cursor: more ? previous!.next : null,
      );
      if (!mounted || request != _page._readGeneration) return;
      if (more &&
          (page.sequence != previous!.sequence || page.asOf != previous.asOf)) {
        throw const AuthError(409, 'REPORT_SNAPSHOT_CHANGED');
      }
      final existing = more ? _page.rows.map(page.itemKey).toSet() : <String>{};
      if (!more) _page.cursors.clear();
      if (page.items.any((r) => existing.contains(page.itemKey(r))) ||
          page.next != null && !_page.cursors.add(page.next!)) {
        throw const FormatException('Repeated financial report page');
      }
      {
        _page._loadedFilters = requestedFilters;
        _page.report = page;
        if (!more) _page.rows.clear();
        _page.rows.addAll(page.items);
        _page.update();
      }
    } catch (failure) {
      if (mounted && request == _page._readGeneration) {
        // Never keep a partial old snapshot beside a new or failed page.
        {
          clear();
          _page.error =
              failure is AuthError && failure.code == 'REPORT_FUND_REQUIRED'
              ? 'ابتدا صندوق یا حساب بانکی را انتخاب کنید.'
              : '${widget.kind == 'treasury' ? 'دریافت گردش صندوق و بانک' : 'دریافت گزارش'}: ${FinancialReportsFX.message(failure)}';
          _page.update();
        }
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
  }

  Future<void> chooseFund() async {
    if (_page.loading) return;
    {
      _page.loading = true;
      clear();
      _page.fund = null;
      _page.update();
    }
    try {
      await _page.fx.authorize();
      final funds = <TreasuryFund>[];
      for (final kind
          in _page.business
              ? ['BANK', 'CASH', 'PETTY_CASH']
              : ['CASH', 'PETTY_CASH']) {
        if (_page.fx.access.has(
          kind == 'BANK' ? 'accounting.bank.read' : 'accounting.treasury.read',
          business: kind == 'BANK',
        )) {
          funds.addAll(await _page.fx.access.funds(kind));
        }
      }
      if (!mounted) return;
      if (funds.isEmpty) {
        throw const AuthError(403, 'REPORT_NO_FUNDS');
      }
      {
        _page.loading = false;
        _page.update();
      }
      final chosen = await MyBottomSheet.view(
        context,
        title: 'انتخاب صندوق یا بانک',
        child: (_) => Column(
          children: [
            for (final item in funds)
              MiniBTN(
                icon: IconsaxPlusLinear.arrow_left_1,
                name:
                    '${item.name}${item.status == 'ARCHIVED' ? ' (بایگانی)' : ''}',
                noFlex: true,
                onTap: () => Get.back(result: item),
              ),
          ],
        ),
      );
      _page.fx.check();
      if (mounted && chosen is TreasuryFund) {
        _page.fund = chosen;
        _page.update();
      }
    } catch (failure) {
      if (mounted) {
        _page.error = failure is AuthError && failure.code == 'REPORT_NO_FUNDS'
            ? 'صندوق یا بانک قابل مشاهده‌ای ندارید؛ مجوز مشاهده خزانه یا بانک نیز لازم است.'
            : 'دریافت فهرست صندوق‌ها و بانک‌ها: ${FinancialReportsFX.message(failure)}';
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    if (mounted && _page.fund != null) await load();
  }

  Future<void> openExpense(Map<String, dynamic> row) async {
    if (_page.loading) return;
    {
      _page.loading = true;
      _page.update();
    }
    try {
      _page.fx.check();
      final expenses = ExpensesFX(_page.fx.context);
      await expenses.authorize();
      if (!expenses.has('accounting.expense.read')) {
        throw const AuthError(403, 'FORBIDDEN');
      }
      if (!mounted) return;
      await Get.toNamed(
        nav_routes.RoutesName.EXPENSE_DETAIL,
        arguments: {'fx': expenses, 'id': row['recordId'] as String},
        preventDuplicates: false,
      );
    } catch (failure) {
      if (mounted) {
        Alert.error(FinancialReportsFX.message(failure), context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    if (mounted) await load();
  }

  Future<void> openInvoice(Map<String, dynamic> row) async {
    if (_page.loading) return;
    {
      _page.loading = true;
      _page.update();
    }
    try {
      _page.fx.check();
      await viewReportedInvoice(
        context,
        appId: _page.fx.context.auth.appId,
        invoiceId: row['recordId'] as String,
        type: row['invoiceType'] as String,
      );
    } catch (failure) {
      if (mounted) {
        Alert.error(FinancialReportsFX.message(failure), context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    if (mounted) await load();
  }

  Widget pair(String title, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(title)),
        const SizedBox(width: 8),
        Expanded(child: Text('$value', textAlign: TextAlign.end)),
      ],
    ),
  );
  Widget money(String key, Object? value) =>
      pair(financialAmountNames[key] ?? key, financialMoney(value));
  List<Widget> amounts(Map value, Iterable<String> fields) => [
    for (final key in fields) money(key, value[key]),
  ];
  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_FinancialReportScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => '',
      header: Header.page(context, text: financialReportNames[widget.kind]!),
      child: (_) => Column(
        children: [
          if (_page.loading) const LinearProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  MyTabBar(
                    tabs: const ['شعبه انتخاب‌شده', 'کل کسب‌وکار'],
                    currentIndex: _page.business ? 1 : 0,
                    divider: false,
                    index: (i) {
                      if (_page.loading || _page.business == (i == 1)) return;
                      if (!_page.fx.has(widget.kind, business: i == 1)) {
                        Alert.error(
                          'مجوز این گزارش را در محدوده انتخاب‌شده ندارید.',
                          context: context,
                        );
                        return;
                      }
                      {
                        _page.business = i == 1;
                        _page.fund = null;
                        clear();
                        _page.update();
                      }
                      if (widget.kind != 'treasury') load();
                    },
                  ),
                  Text(
                    _page.business
                        ? 'محدوده: کل کسب‌وکار'
                        : 'محدوده: ${_page.fx.context.selectedBranch?.name ?? _page.fx.branchId}',
                  ),
                  if (widget.kind != 'balances') ...[
                    DateInput(
                      controller: _page.start,
                      name: 'از تاریخ',
                      onChanged: (_) {
                        clear();
                        _page.update();
                      },
                      enabled: !_page.loading,
                    ),
                    DateInput(
                      controller: _page.end,
                      name: 'تا تاریخ (شامل این روز)',
                      onChanged: (_) {
                        clear();
                        _page.update();
                      },
                      enabled: !_page.loading,
                    ),
                  ],
                  if (widget.kind == 'dues')
                    MyTabBar(
                      tabs: const ['تعهدات', 'چک‌های در انتظار'],
                      divider: false,
                      currentIndex: _page.section == 'OBLIGATIONS' ? 0 : 1,
                      index: (i) {
                        if (!_page.loading) {
                          _page.section = i == 0 ? 'OBLIGATIONS' : 'CHEQUES';
                          load();
                        }
                      },
                    ),
                  if (widget.kind == 'expenses')
                    MyTabBar(
                      tabs: const ['دسته‌بندی', 'شعبه'],
                      divider: false,
                      currentIndex: _page.groupBy == 'CATEGORY' ? 0 : 1,
                      index: (i) {
                        if (!_page.loading) {
                          _page.groupBy = i == 0 ? 'CATEGORY' : 'BRANCH';
                          load();
                        }
                      },
                    ),
                  if (widget.kind == 'treasury')
                    MiniBTN(
                      icon: IconsaxPlusLinear.arrow_left_1,
                      name: _page.fund?.name ?? 'انتخاب صندوق یا بانک',
                      noFlex: true,
                      onTap: _page.loading ? null : chooseFund,
                    ),
                  BTN(
                    name: 'دریافت گزارش',
                    disabled: _page.loading,
                    onTap: load,
                  ),
                  if (_page.error != null)
                    Text(_page.error!, textAlign: TextAlign.center),
                  if (_page.report != null) ...body(_page.report!),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  List<Widget> body(FinancialReportPage page) {
    final json = page.json;
    return [
      MyDivider(text: 'خلاصه گزارش'),
      pair('زمان تهیه', DateConvertor.grigoriToJalali(page.asOf)),
      if (['balances', 'dues'].contains(widget.kind)) ...[
        pair('تعداد اسناد', (json['totals'] as Map)['count']),
        ...amounts(json['totals'] as Map, financialAmountNames.keys.take(4)),
        const Text(
          'چک در انتظار تا وصول، جزو مانده تعهد باقی می‌ماند؛ مبالغ این بخش‌ها را با هم جمع نکنید.',
          textAlign: TextAlign.center,
        ),
        if (!_page.business)
          const Text(
            'وام‌ها و اعتبار طرف‌حساب در سطح کل کسب‌وکار در مانده شعبه محاسبه نمی‌شوند.',
            textAlign: TextAlign.center,
          ),
        if (widget.kind == 'dues' &&
            _page.business &&
            _page.section == 'OBLIGATIONS')
          const Text(
            'سررسید تعهدات شامل برنامه قراردادی وام و هزینه‌های هنوز شناسایی‌نشده آن نیز می‌شود.',
            textAlign: TextAlign.center,
          ),
        if (widget.kind == 'balances' && json['creditBalances'] != null)
          ...credits(json['creditBalances'] as Map),
      ],
      if (widget.kind == 'expenses') ...[
        ...amounts(json['totals'] as Map, FinancialReportPage.expenseFields),
        const Text(
          'پرداخت‌ها وضعیت فعلی اسناد تاریخ‌خورده در این بازه‌اند؛ گردش وجه همین دوره یا هزینه اضافه نیستند. هزینه سرمایه‌ای و اصل وام، هزینه عملیاتی نیست.',
          textAlign: TextAlign.center,
        ),
      ],
      if (['cash-flow', 'treasury'].contains(widget.kind)) ...[
        money('openingBalance', json['openingBalance']),
        ...amounts(widget.kind == 'treasury' ? json : json['totals'] as Map, [
          'inflow',
          'outflow',
        ]),
        money('closingBalance', json['closingBalance']),
        if (widget.kind == 'cash-flow') ...[
          MyDivider(text: 'گردش خارج از انتقال داخلی'),
          ...amounts(json['externalCashflow'] as Map, [
            'inflow',
            'outflow',
            'net',
          ]),
          if (json['sharedBankExcluded'] == true)
            const Text(
              'گردش شعبه فقط صندوق و تنخواه را پوشش می‌دهد؛ بانک مشترک خارج از این گزارش است.',
              textAlign: TextAlign.center,
            ),
          if (json['unclassified'] == true)
            const Text(
              'بخشی از گردش، طبقه‌بندی مالی مشخص ندارد.',
              textAlign: TextAlign.center,
            ),
        ],
        if (widget.kind == 'treasury') ...[
          MyDivider(text: 'وضعیت فعلی صندوق یا بانک'),
          ...amounts(json['current'] as Map, [
            'balance',
            'heldAmount',
            'availableAmount',
            'unreconciledAmount',
          ]),
        ],
      ],
      MyDivider(text: 'جزئیات'),
      if (_page.rows.isEmpty) const Text('اطلاعاتی برای این گزارش وجود ندارد.'),
      for (final row in _page.rows) ...rowWidgets(page, row),
      if (page.next != null)
        BTN(
          name: 'نمایش بیشتر',
          disabled: _page.loading,
          onTap: () => load(more: true),
        ),
    ];
  }

  List<Widget> credits(Map credit) => [
    MyDivider(text: 'اعتبار و حساب طرف‌حساب‌ها'),
    const Text(
      'این مانده‌ها و اعتبارهای تخصیص‌نیافته جداگانه‌اند؛ به تعهدات بالا اضافه نمی‌شوند.',
      textAlign: TextAlign.center,
    ),
    for (final row in credit['partyAccounts'] as List) ...[
      pair('نوع طرف حساب', partyName(row['partyType'] as String)),
      pair('بدهکار', '${row['debt'].toString().seRagham()} تومان'),
      pair('بستانکار', '${row['credit'].toString().seRagham()} تومان'),
    ],
    for (final section in {
      'unallocatedCredit': 'اعتبار تخصیص‌نیافته',
      'classifiedAdvances': 'پیش‌پرداخت طبقه‌بندی‌شده',
      'clearing': 'حساب واسط',
    }.entries)
      for (final row in credit[section.key] as List)
        pair(
          '${section.value} (${partyName((row['partyType'] ?? row['kind']) as String)})',
          financialMoney(row['amount']),
        ),
  ];
  String partyName(String value) =>
      const {
        'CUSTOMER': 'مشتری',
        'SUPPLIER': 'تامین‌کننده',
        'CARD': 'کارت',
        'CLEARING': 'تسویه',
        'UNRECONCILED': 'تطبیق‌نشده',
        'PAYOUT_VARIANCE': 'مغایرت تسویه',
      }[value] ??
      value;
  List<Widget> rowWidgets(FinancialReportPage page, Map<String, dynamic> row) {
    if (['balances', 'dues'].contains(widget.kind)) {
      return [
        pair(
          'نوع سند',
          const {
                'INVOICE': 'فاکتور',
                'EXPENSE': 'هزینه',
                'ASSET': 'دارایی',
                'LOAN': 'وام',
                'LOAN_INSTALLMENT': 'قسط وام',
                'PAYMENT_CHEQUE': 'چک طرف‌حساب',
                'EXPENSE_CHEQUE': 'چک هزینه',
                'ASSET_CHEQUE': 'چک دارایی',
                'LOAN_CHEQUE': 'چک وام',
              }[row['source']] ??
              row['source'],
        ),
        if (row['name'] != null) pair('نام', row['name']),
        if (row['title'] != null) pair('عنوان', row['title']),
        if (row['number'] != null) pair('شماره', row['number']),
        pair('جهت', row['direction'] == 'IN' ? 'دریافتنی' : 'پرداختنی'),
        pair('مبلغ مانده', '${row['amount'].toString().seRagham()} تومان'),
        if (row['pendingAmount'] != null)
          pair(
            'از این مبلغ، در انتظار',
            '${row['pendingAmount'].toString().seRagham()} تومان',
          ),
        pair(
          'سررسید',
          row['dueAt'] == null
              ? 'ثبت نشده'
              : DateConvertor.grigoriToJalali(row['dueAt']),
        ),
        pair(
          'سررسیدگذشته',
          '${row['overdueAmount'].toString().seRagham()} تومان',
        ),
        if (row['source'] == 'EXPENSE' &&
            row['branchId'] == _page.fx.branchId &&
            _page.fx.access.has('accounting.expense.read'))
          MiniBTN(
            icon: IconsaxPlusLinear.arrow_left_1,
            name: 'مشاهده سند هزینه',
            noFlex: true,
            onTap: _page.loading ? null : () => openExpense(row),
          ),
        if (row['source'] == 'INVOICE' &&
            row['branchId'] == _page.fx.branchId &&
            ['SALE', 'PURCHASE'].contains(row['invoiceType']) &&
            _page.fx.access.has(
              row['invoiceType'] == 'SALE'
                  ? 'accounting.sale.read'
                  : 'accounting.purchase.read',
            ))
          MiniBTN(
            icon: IconsaxPlusLinear.arrow_left_1,
            name: 'مشاهده فاکتور',
            noFlex: true,
            onTap: _page.loading ? null : () => openInvoice(row),
          ),
        pair('شناسه سند', row['recordId']),
        MyDivider(),
      ];
    }
    if (widget.kind == 'expenses') {
      return [
        pair('عنوان گروه', row['name']),
        ...amounts(row, FinancialReportPage.expenseFields),
        MyDivider(),
      ];
    }
    if (widget.kind == 'cash-flow') {
      return [
        pair(
          'نوع گردش',
          const {
                'OPERATING': 'عملیاتی',
                'INVESTING': 'سرمایه‌گذاری',
                'FINANCING': 'تامین مالی',
                'INTERNAL_TRANSFER': 'انتقال داخلی',
                'OPENING': 'افتتاحیه',
                'CASH_ADJUSTMENT': 'اصلاح صندوق',
                'UNCLASSIFIED': 'طبقه‌بندی‌نشده',
              }[row['category']] ??
              row['category'],
        ),
        ...amounts(row, ['inflow', 'outflow', 'net']),
        MyDivider(),
      ];
    }
    return [
      pair('تاریخ', DateConvertor.grigoriToJalali(row['occurredAt'])),
      if (row['description'] != null) pair('شرح', row['description']),
      pair('نوع سند', row['sourceType']),
      pair('شناسه سند', row['sourceId']),
      ...amounts(row, ['inflow', 'outflow']),
      MyDivider(),
    ];
  }

  @override
  void didUpdateWidget(covariant FinancialReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

Widget buildFinancialReportRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return FinancialReportScreen(
    fx: args.required<FinancialReportsFX>('fx'),
    kind: args.required<String>('kind'),
  );
}
