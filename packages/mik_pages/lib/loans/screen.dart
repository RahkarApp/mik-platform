import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:get/get.dart';
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/loader.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/loan.dart';
import 'package:mik_data/source/remote/models/remote_json.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/loans.dart';
import 'package:mik_utils/public/date.dart';

import '../reports/financial_screen.dart' show financialMoney;
import 'forms.dart';

class LoansScreen extends StatefulWidget {
  final String appId;
  final String? loanId;
  const LoansScreen({required this.appId, this.loanId, super.key});
  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenController extends GetxController {
  RealtimeWatch? _realtime;
  int _readGeneration = 0;
  LoansFX? fx;
  List<RemoteLoan> rows = [];
  RemoteLoan? loan;
  List<LoanInstallment> installments = [];
  List<LoanPayment> payments = [];
  bool loading = true, opening = false;
  String? error;
}

class _LoansScreenState extends State<LoansScreen> {
  late final _page = _LoansScreenController();

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
          'accounting.loan',
          'accounting.loan-installment',
          'accounting.loan-payment',
          'accounting.loan-entry',
          'accounting.loan-cheque-followup',
        },
        () async {
          await load(background: true);
        },
        busy: () => _page.loading || _page.opening,
        invalidate: () {
          if (mounted) {
            {
              _page._readGeneration++;
              _page.loading = false;
              _page.rows = [];
              _page.loan = null;
              _page.installments = [];
              _page.payments = [];
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

  Future<void> load({bool background = false}) async {
    if (!mounted) return;
    final request = ++_page._readGeneration;
    {
      if (!background) _page.loading = true;
      _page.error = null;
      if (!background) _page.rows = [];
      if (!background) _page.loan = null;
      if (!background) _page.installments = [];
      if (!background) _page.payments = [];
      _page.update();
    }
    try {
      final context = BusinessContext.forApp(widget.appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= LoansFX(context);
      await _page.fx!.authorize();
      await _page.fx!.restore();
      if (widget.loanId == null) {
        final result = await _page.fx!.all();
        if (mounted && request == _page._readGeneration) _page.rows = result;
      } else {
        final detail = await _page.fx!.detail(widget.loanId!);
        final paid = await _page.fx!.payments(detail.loan.id);
        if (mounted && request == _page._readGeneration) {
          _page.loan = detail.loan;
          _page.installments = detail.installments;
          _page.payments = paid;
        }
      }
    } catch (failure) {
      if (mounted && request == _page._readGeneration) {
        _page.error = loanMessage(failure);
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

  Future<void> form(
    String action, {
    String? installmentId,
    String? paymentId,
  }) async {
    if (_page.loading || _page.opening || _page.fx == null) return;
    {
      _page.opening = true;
      _page.update();
    }
    await ([
          'reschedule',
          'waive',
          'reverse',
          'cheque',
        ].contains(_page.fx!.pending?.action ?? action)
        ? Get.toNamed(
            nav_routes.RoutesName.LOAN_MANAGEMENT_FORM,
            arguments: {
              'fx': _page.fx!,
              'action': _page.fx!.pending?.action ?? action,
              'loanId': widget.loanId,
              'installmentId': installmentId,
              'paymentId': paymentId,
            },
            preventDuplicates: false,
          )
        : Get.toNamed(
            nav_routes.RoutesName.LOAN_FORM,
            arguments: {
              'fx': _page.fx!,
              'action': _page.fx!.pending?.action ?? action,
              'loanId': widget.loanId,
            },
            preventDuplicates: false,
          ));
    if (mounted) {
      {
        _page.opening = false;
        _page.update();
      }
      await load();
    }
  }

  Widget pair(String name, String value) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        Expanded(child: Text(name)),
        const SizedBox(width: 10),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
  Widget details() => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      pair('عنوان', _page.loan!.json['name'] as String),
      pair('نوع', loanDirections[_page.loan!.json['direction']]!),
      pair('وضعیت', loanStatuses[_page.loan!.status]!),
      pair(
        'طرف قرارداد',
        RemoteJson(_page.loan!.json['counterparty']).text('name'),
      ),
      for (final field in RemoteLoan.summary.entries)
        pair(field.value, financialMoney(_page.loan!.money(field.key))),
      MyDivider(text: 'مبالغ ثبت‌شده'),
      for (final field in RemoteLoan.amounts.entries)
        pair(field.value, financialMoney(_page.loan!.money(field.key))),
      if (_page.loan!.json['fundedAt'] != null)
        pair(
          'تاریخ جابه‌جایی اصل وجه',
          DateConvertor.grigoriToJalali(_page.loan!.json['fundedAt'] as String),
        ),
      if (_page.loan!.json['note'] != null)
        pair('یادداشت', _page.loan!.json['note'] as String),
      if (_page.fx!.pending == null) ...[
        if (_page.loan!.status == 'DRAFT' && _page.fx!.has('fund'))
          BTN(
            name: 'ثبت جابه‌جایی اصل وام',
            disabled: _page.opening,
            onTap: () => form('fund'),
            navigate: true,
          ),
        if (_page.loan!.status == 'DRAFT' && _page.fx!.has('manage'))
          MiniBTN(
            name: 'لغو پیش‌نویس',
            icon: IconsaxPlusLinear.close_circle,
            noFlex: true,
            onTap: _page.opening ? null : () => form('cancel'),
          ),
        if (_page.loan!.status == 'ACTIVE' && _page.fx!.has('pay'))
          BTN(
            name: 'ثبت بازپرداخت',
            disabled: _page.opening,
            onTap: () => form('payment'),
          ),
      ],
      MyDivider(text: 'برنامه اقساط'),
      const Text(
        'مانده اقساط شامل مبالغ رزروشده با چک نیز هست؛ پرداخت قابل تخصیص را سرور تعیین می‌کند.',
      ),
      for (final row in _page.installments) ...[
        pair(
          'قسط ${row.json['number']}',
          DateConvertor.grigoriToJalali(row.json['dueAt'] as String),
        ),
        pair('اصل قسط', financialMoney(row.money('principalAmount'))),
        pair('هزینه/درآمد قسط', financialMoney(row.money('chargeAmount'))),
        if (row.json.containsKey('outstandingPrincipal'))
          pair('مانده اصل', financialMoney(row.money('outstandingPrincipal'))),
        if (row.json.containsKey('outstandingCharge'))
          pair(
            'مانده هزینه/درآمد',
            financialMoney(row.money('outstandingCharge')),
          ),
        pair(
          'اصل در انتظار',
          financialMoney(row.money('pendingPrincipalAmount')),
        ),
        pair(
          'هزینه در انتظار',
          financialMoney(row.money('pendingChargeAmount')),
        ),
        if (row.json['status'] != null)
          pair(
            'وضعیت قسط',
            const {
              'PAID': 'پرداخت‌شده',
              'OVERDUE': 'سررسید گذشته',
              'SCHEDULED': 'برنامه‌ریزی‌شده',
            }[row.json['status']]!,
          ),
        if (_page.fx!.pending == null &&
            ['DRAFT', 'ACTIVE'].contains(_page.loan!.status) &&
            _page.fx!.has('manage'))
          MiniBTN(
            name: 'تغییر سررسید قسط ${row.json['number']}',
            icon: IconsaxPlusLinear.calendar_edit,
            noFlex: true,
            onTap: _page.opening
                ? null
                : () => form('reschedule', installmentId: row.id),
          ),
        if (_page.fx!.pending == null &&
            _page.loan!.status == 'ACTIVE' &&
            _page.fx!.has('waive') &&
            row.money('chargeAmount') -
                    row.money('waivedChargeAmount') -
                    row.money('paidChargeAmount') -
                    row.money('pendingChargeAmount') >
                0)
          MiniBTN(
            name: 'بخشودگی هزینه قسط ${row.json['number']}',
            icon: IconsaxPlusLinear.receipt_discount,
            noFlex: true,
            onTap: _page.opening
                ? null
                : () => form('waive', installmentId: row.id),
          ),
        EndLine(),
      ],
      MyDivider(text: 'بازپرداخت‌ها'),
      if (_page.payments.isEmpty) EmptyList(text: 'بازپرداختی ثبت نشده است.'),
      for (final payment in _page.payments) ...[
        pair(
          DateConvertor.grigoriToJalali(payment.json['occurredAt'] as String),
          financialMoney(payment.money('amount')),
        ),
        pair(
          'وضعیت',
          const {
            'PENDING': 'در انتظار',
            'CONFIRMED': 'قطعی',
            'BOUNCED': 'برگشتی',
            'RETURNED': 'عودت‌شده',
            'REVERSED': 'برگشت وجه',
          }[payment.json['status']]!,
        ),
        pair('اصل', financialMoney(payment.money('principalAmount'))),
        pair('هزینه/درآمد', financialMoney(payment.money('chargeAmount'))),
        pair(
          'صندوق/حساب',
          RemoteJson(payment.json['routing']).text('fundName'),
        ),
        if (payment.json['cheque'] != null) ...[
          pair('شماره چک', RemoteJson(payment.json['cheque']).text('number')),
          pair('بانک چک', RemoteJson(payment.json['cheque']).text('bankName')),
          pair(
            'سررسید چک',
            DateConvertor.grigoriToJalali(
              RemoteJson(payment.json['cheque']).text('dueAt'),
            ),
          ),
        ],
        if (_page.fx!.pending == null &&
            payment.json['status'] == 'CONFIRMED' &&
            _page.fx!.has('reverse'))
          MiniBTN(
            name: 'برگشت بازپرداخت',
            icon: IconsaxPlusLinear.undo,
            noFlex: true,
            onTap: _page.opening
                ? null
                : () => form(
                    'reverse',
                    paymentId: payment.json['loanPaymentId'] as String,
                  ),
          ),
        if (_page.fx!.pending == null &&
            payment.json['status'] == 'PENDING' &&
            payment.json['method'] == 'CHEQUE' &&
            _page.fx!.has('pay') &&
            _page.fx!.access.has('accounting.cheque.clear'))
          MiniBTN(
            name: 'تعیین نتیجه چک',
            icon: IconsaxPlusLinear.card_tick,
            noFlex: true,
            onTap: _page.opening
                ? null
                : () => form(
                    'cheque',
                    paymentId: payment.json['loanPaymentId'] as String,
                  ),
          ),
        EndLine(),
      ],
      BTN(name: 'دریافت مجدد اطلاعات', disabled: _page.opening, onTap: load),
    ],
  );
  @override
  Widget build(BuildContext context) => GetBuilder<_LoansScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => '',
      header: Header.page(context, text: 'وام‌ها و اقساط'),
      floatingActionButton:
          widget.loanId == null &&
              !_page.loading &&
              !_page.opening &&
              _page.error == null &&
              _page.fx?.has('manage') == true &&
              _page.fx?.pending == null
          ? MyFAB(
              icon: IconsaxPlusLinear.add,
              text: 'وام جدید',
              onTap: () => form('create'),
            )
          : null,
      child: (_) => Column(
        children: [
          if (_page.loading || _page.opening) const Loader(),
          if (_page.error != null) ...[
            Text(_page.error!),
            BTN(name: 'تلاش مجدد', onTap: load),
          ],
          if (!_page.loading && _page.error == null) ...[
            if (_page.fx?.pending != null)
              BTN(
                name: 'پیگیری ثبت قبلی وام',
                onTap: () => form(_page.fx!.pending!.action),
              ),
            Expanded(
              child: _page.loan != null
                  ? details()
                  : _page.rows.isEmpty
                  ? EmptyList(
                      text: 'وامی ثبت نشده است.',
                      icon: IconsaxPlusLinear.money,
                    )
                  : RefreshIndicator(
                      onRefresh: load,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 70),
                        itemCount: _page.rows.length,
                        itemBuilder: (context, index) {
                          final row = _page.rows[index];
                          return InkWell(
                            onTap: _page.opening
                                ? null
                                : () async {
                                    await Get.toNamed(
                                      nav_routes.RoutesName.LOANS,
                                      arguments: {
                                        'appId': widget.appId,
                                        'loanId': row.id,
                                      },
                                      preventDuplicates: false,
                                    );
                                    if (mounted) await load();
                                  },
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      const CircleAvatar(
                                        child: Icon(IconsaxPlusLinear.money),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(row.json['name'] as String),
                                            Text(
                                              '${loanDirections[row.json['direction']]} — ${loanStatuses[row.status]}',
                                            ),
                                            Text(
                                              'اصل قرارداد: ${financialMoney(row.money('principalAmount'))}',
                                            ),
                                            Text(
                                              'مانده اصل: ${financialMoney(row.money('outstandingPrincipal'))}',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                EndLine(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget buildLoansRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return LoansScreen(
    appId: args.required<String>('appId'),
    loanId: args.optional<String>('loanId'),
  );
}
