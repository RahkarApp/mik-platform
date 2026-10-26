import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_data/utils/fx/party_account.dart';
import 'package:mik_data/utils/fx/payment_list.dart';
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:mik_data/source/remote/models/invoice_payment.dart';

import '../invoice/read_screen.dart' show viewReportedInvoice;

import 'package:mik_utils/public/date.dart';

import '../reports/financial_screen.dart' show financialMoney;

class PartyAccountScreen extends StatefulWidget {
  final String appId, partyType, partyId;
  const PartyAccountScreen({
    required this.appId,
    required this.partyType,
    required this.partyId,
    super.key,
  });
  @override
  State<PartyAccountScreen> createState() => _PartyAccountScreenState();
}

class _PartyAccountScreenController extends GetxController {
  PartyAccountFX? fx;
  PartyAccountPage? page;
  final entries = <Map<String, dynamic>>[];
  final section = 'گردش حساب'.obs;
  List<InvoicePartyPayment> payments = [];
  List<InvoiceSettlementSource> sources = [];
  String? nextReference;
  int generation = 0;
  bool loading = false, opening = false;
  RealtimeWatch? realtime;
  String? error;
}

class _PartyAccountScreenState extends State<PartyAccountScreen> {
  late final _page = _PartyAccountScreenController();

  @override
  void initState() {
    super.initState();
    final active = BusinessContext.forApp(widget.appId);
    if (active != null) {
      _page.fx = PartyAccountFX(active, widget.partyType, widget.partyId);
      _page.realtime = RealtimeWatch(
        RealtimeFX.forContext(active),
        {
          'accounting.account',
          'accounting.entry',
          'accounting.source',
          'accounting.allocation',
          'accounting.payment',
          'accounting.cheque',
          'accounting.sale',
          'accounting.purchase',
        },
        () async {
          await load(background: true);
        },
        busy: () => _page.loading || _page.opening,
        invalidate: () {
          if (mounted) {
            {
              _page.generation++;
              _page.loading = false;
              _page.page = null;
              _page.entries.clear();
              _page.payments = [];
              _page.sources = [];
              _page.nextReference = null;
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

  @override
  void dispose() {
    _page.generation++;
    _page.realtime?.dispose();
    _page.section.close();
    super.dispose();
  }

  Future<void> load({bool more = false, bool background = false}) async {
    if (_page.loading) return;
    final request = ++_page.generation;
    final selected = _page.section.value;
    if (more &&
        (selected == 'گردش حساب'
            ? _page.page?.next == null
            : _page.nextReference == null)) {
      return;
    }
    {
      if (!background) _page.loading = true;
      _page.error = null;
      if (!more && !background) {
        _page.page = null;
        _page.entries.clear();
        _page.payments = [];
        _page.sources = [];
        _page.nextReference = null;
      }
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= PartyAccountFX(active, widget.partyType, widget.partyId);
      final result = await _page.fx!.page(
        after: more && selected == 'گردش حساب' ? _page.page!.next! : 0,
      );
      final paymentPage = selected == 'دریافت و پرداخت'
          ? await _page.fx!.payments(after: more ? _page.nextReference : null)
          : null;
      final sourcePage = selected == 'اعتبار مصرف‌نشده'
          ? await _page.fx!.sources(after: more ? _page.nextReference : null)
          : null;
      if (!mounted || request != _page.generation) return;
      if (more) {
        // There is no snapshot token: restart if the visible summary changed.
        for (final key in [
          'accountId',
          'balance',
          'debt',
          'credit',
          'availableCredit',
          'invoiceOutstanding',
          'overdueAmount',
          'pendingChequeAmount',
          'operationPending',
        ]) {
          if (_page.page!.summary[key] != result.summary[key]) {
            throw const AuthError(409, 'REPORT_SNAPSHOT_CHANGED');
          }
        }
        if (selected == 'گردش حساب' &&
            result.items.any(
              (r) => _page.entries.any((e) => e['entryId'] == r['entryId']),
            )) {
          throw const FormatException('Repeated account entry');
        }
      }
      {
        if (!more) {
          _page.entries.clear();
          _page.payments = [];
          _page.sources = [];
          _page.nextReference = null;
        }
        _page.page = result;
        if (selected == 'گردش حساب') _page.entries.addAll(result.items);
        if (paymentPage != null) {
          if (paymentPage.items.any(
            (row) => _page.payments.any((old) => old.id == row.id),
          )) {
            throw const FormatException('Repeated account payment');
          }
          _page.payments.addAll(paymentPage.items);
          _page.nextReference = paymentPage.next;
        }
        if (sourcePage != null) {
          if (sourcePage.items.any(
            (row) => _page.sources.any((old) => old.id == row.id),
          )) {
            throw const FormatException('Repeated account source');
          }
          _page.sources.addAll(sourcePage.items);
          _page.nextReference = sourcePage.next;
        }
        _page.update();
      }
    } catch (failure) {
      if (!mounted || request != _page.generation) return;
      // Do not keep financial data visible after access or context changes.
      {
        _page.page = null;
        _page.entries.clear();
        _page.payments = [];
        _page.sources = [];
        _page.nextReference = null;
        _page.error = FinancialReportsFX.message(failure);
        _page.update();
      }
      Alert.error(_page.error!, context: context);
    } finally {
      if (mounted && request == _page.generation) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  Future<void> openReference(String kind, String id) async {
    if (_page.opening || _page.loading) return;
    {
      _page.opening = true;
      _page.update();
    }
    try {
      if (kind == 'INVOICE') {
        final detail = await _page.fx!.invoice(id);
        if (!mounted) return;
        await viewReportedInvoice(
          context,
          appId: widget.appId,
          invoiceId: detail.summary.id,
          type: detail.summary.type,
        );
      } else if (kind == 'PAYMENT') {
        final detail = await PaymentListFX(_page.fx!.context).detail(id);
        final payment = detail.payment;
        _page.fx!.party(payment.businessId, payment.partyType, payment.partyId);
        if (!mounted) return;
        await MyBottomSheet.view(
          context,
          title: payment.direction == 'IN' ? 'جزئیات دریافت' : 'جزئیات پرداخت',
          child: (scroll) => SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                pair('مبلغ', financialMoney(payment.amount)),
                pair(
                  'روش',
                  const {
                        'CASH': 'نقدی',
                        'CARD': 'کارت',
                        'BANK_TRANSFER': 'انتقال بانکی',
                        'CHEQUE': 'چک',
                        'ONLINE': 'آنلاین',
                      }[payment.method] ??
                      payment.method,
                ),
                pair(
                  'وضعیت',
                  const {
                        'PENDING': 'در انتظار',
                        'CONFIRMED': 'تأییدشده',
                        'BOUNCED': 'برگشتی',
                        'RETURNED': 'عودت‌شده',
                        'REVERSED': 'معکوس‌شده',
                      }[payment.status] ??
                      payment.status,
                ),
                if (detail.reference != null)
                  pair('شماره پیگیری', detail.reference!),
                if (detail.note != null) ...[
                  MyDivider(text: 'توضیحات'),
                  Text(detail.note!),
                ],
                BTN(name: 'بستن', onTap: () => Get.back()),
              ],
            ),
          ),
        );
      } else {
        throw const AuthError(409, 'ACCOUNT_DOCUMENT_UNSUPPORTED');
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(
          failure is AuthError &&
                  failure.code == 'ACCOUNT_DOCUMENT_OTHER_BRANCH'
              ? 'این فاکتور متعلق به شعبه دیگری است؛ برای مشاهده آن شعبه مربوط را انتخاب کنید.'
              : failure is AuthError &&
                    failure.code == 'ACCOUNT_DOCUMENT_UNSUPPORTED'
              ? 'نمایش مستقیم این نوع سند هنوز در دسترس نیست؛ شناسه مرجع در گردش حساب موجود است.'
              : FinancialReportsFX.message(failure),
          context: context,
        );
      }
    } finally {
      if (mounted) {
        {
          _page.opening = false;
          if (!_page.fx!.context.valid ||
              _page.fx!.context.selectedBranch?.branchId != _page.fx!.branch) {
            _page.page = null;
            _page.entries.clear();
            _page.payments = [];
            _page.sources = [];
            _page.nextReference = null;
          }
          _page.update();
        }
        if (kind == 'INVOICE' && _page.page != null) await load();
      }
    }
  }

  Future<void> addPayment() async {
    if (_page.loading || _page.opening) return;
    {
      _page.opening = true;
      _page.update();
    }
    try {
      await Get.toNamed(
        nav_routes.RoutesName.PARTY_PAYMENT,
        arguments: {
          'appId': widget.appId,
          'partyType': widget.partyType,
          'partyId': widget.partyId,
        },
        preventDuplicates: false,
      );
    } finally {
      if (mounted) {
        {
          _page.opening = false;
          _page.update();
        }
        await load();
      }
    }
  }

  String reasonName(String value) =>
      const {
        'INVOICE': 'ثبت فاکتور',
        'CREDIT_NOTE': 'سند بستانکار',
        'RECEIPT': 'ثبت تسویه',
        'REFUND': 'استرداد وجه',
        'CHEQUE_CLEARED': 'وصول چک',
        'CHEQUE_PAID': 'پرداخت چک',
        'PROVIDER_RECEIPT': 'تسویه از درگاه',
      }[value] ??
      value;
  String referenceName(String value) =>
      const {
        'INVOICE': 'فاکتور',
        'PAYMENT': 'پرداخت',
        'INVOICE_AMENDMENT': 'اصلاح فاکتور',
        'PAYMENT_REVERSAL': 'برگشت پرداخت',
      }[value] ??
      value;
  Widget pair(String label, String value) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_PartyAccountScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => '',
      header: Header.page(context, text: 'صورت‌حساب و گردش حساب'),
      child: (_) => Column(
        children: [
          if (_page.loading) const LinearProgressIndicator(),
          if (_page.error != null)
            Text(_page.error!, textAlign: TextAlign.center),
          MyTab(
            tab: const ['گردش حساب', 'دریافت و پرداخت', 'اعتبار مصرف‌نشده'],
            value: _page.section,
            enabledValues: _page.loading || _page.opening ? <String>{} : null,
            callback: (value) {
              _page.section.value = value as String;
              load();
            },
          ),
          Expanded(
            child: ListView(
              children: [
                if (_page.page != null) ...[
                  Text(
                    '${(_page.page!.summary['party'] as Map)['name']}',
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'حساب کل کسب‌وکار؛ شامل همه شعب',
                    textAlign: TextAlign.center,
                  ),
                  MyDivider(),
                  for (final field in {
                    'balance': widget.partyType == 'SUPPLIER'
                        ? 'مانده (مثبت: بدهی ما، منفی: طلب ما)'
                        : 'مانده (مثبت: طلب ما، منفی: بدهی ما)',
                    'debt': widget.partyType == 'SUPPLIER'
                        ? 'بدهی ما به تأمین‌کننده'
                        : 'طلب ما از مشتری',
                    'credit': widget.partyType == 'SUPPLIER'
                        ? 'طلب ما از تأمین‌کننده'
                        : 'بدهی ما به مشتری',
                    'availableCredit': 'اعتبار قابل استفاده',
                    'invoiceOutstanding': 'مانده فاکتورهای تسویه‌نشده',
                    'overdueAmount': 'مانده سررسیدگذشته',
                    'pendingChequeAmount': 'چک‌های در انتظار',
                  }.entries)
                    pair(
                      field.value,
                      financialMoney(_page.page!.money(field.key)),
                    ),
                  if (_page.page!.summary['operationPending'] != null)
                    const Text('عملیات مالی این حساب هنوز در حال تکمیل است.'),
                  if (_page.fx?.canCreatePayment == true)
                    BTN(
                      name: widget.partyType == 'CUSTOMER'
                          ? 'ثبت دریافت وجه'
                          : 'ثبت پرداخت وجه',
                      disabled: _page.loading || _page.opening,
                      onTap: addPayment,
                    ),
                  MyDivider(text: 'گردش حساب'),
                  if (_page.section.value == 'گردش حساب' &&
                      _page.entries.isEmpty)
                    const Text(
                      'گردشی ثبت نشده است.',
                      textAlign: TextAlign.center,
                    ),
                  if (_page.section.value == 'دریافت و پرداخت' &&
                      _page.payments.isEmpty)
                    const Text('دریافت یا پرداختی ثبت نشده است.'),
                  for (final row in _page.payments) ...[
                    pair(
                      row.direction == 'IN' ? 'دریافت' : 'پرداخت',
                      financialMoney(row.amount),
                    ),
                    pair(
                      'وضعیت',
                      const {
                            'PENDING': 'در انتظار',
                            'CONFIRMED': 'تأییدشده',
                            'BOUNCED': 'برگشتی',
                            'RETURNED': 'عودت‌شده',
                            'REVERSED': 'معکوس‌شده',
                          }[row.status] ??
                          row.status,
                    ),
                    MiniBTN(
                      name: 'مشاهده پرداخت',
                      icon: IconsaxPlusLinear.document_text,
                      noFlex: true,
                      onTap: _page.opening
                          ? null
                          : () => openReference('PAYMENT', row.id),
                    ),
                    MyDivider(),
                  ],
                  if (_page.section.value == 'اعتبار مصرف‌نشده' &&
                      !_page.sources.any((row) => row.available > 0))
                    const Text('اعتبار مصرف‌نشده‌ای در این صفحه وجود ندارد.'),
                  for (final row in _page.sources.where(
                    (row) => row.available > 0,
                  )) ...[
                    pair(
                      row.kind == 'PAYMENT'
                          ? 'اعتبار دریافت/پرداخت'
                          : 'اعتبار سند بستانکار',
                      financialMoney(row.available),
                    ),
                    pair('مبلغ اولیه', financialMoney(row.amount)),
                    pair('مصرف‌شده', financialMoney(row.usedAmount)),
                    if (row.restrictedRootId != null)
                      const Text(
                        'این اعتبار فقط برای فاکتور مشخص‌شده قابل استفاده است.',
                      ),
                    MiniBTN(
                      name: 'مشاهده سند اعتبار',
                      icon: IconsaxPlusLinear.document_text,
                      noFlex: true,
                      onTap: _page.opening
                          ? null
                          : () => openReference(
                              row.kind == 'PAYMENT' ? 'PAYMENT' : 'INVOICE',
                              row.referenceId,
                            ),
                    ),
                    MyDivider(),
                  ],
                  for (final row in _page.entries) ...[
                    pair(
                      'تاریخ',
                      DateConvertor.grigoriToJalali(row['createdAt'] as String),
                    ),
                    pair('تغییر مانده', financialMoney(row['delta'])),
                    pair('مانده پس از ثبت', financialMoney(row['balance'])),
                    pair('علت ثبت', reasonName(row['reason'] as String)),
                    pair(
                      'نوع مرجع',
                      referenceName(row['referenceType'] as String),
                    ),
                    SelectableText('شناسه مرجع: ${row['referenceId']}'),
                    if (['INVOICE', 'PAYMENT'].contains(row['referenceType']))
                      MiniBTN(
                        name: 'مشاهده سند مرتبط',
                        icon: IconsaxPlusLinear.document_text,
                        noFlex: true,
                        onTap: _page.opening
                            ? null
                            : () => openReference(
                                row['referenceType'] as String,
                                row['referenceId'] as String,
                              ),
                      ),
                    MyDivider(),
                  ],
                  if (_page.section.value == 'گردش حساب'
                      ? _page.page!.next != null
                      : _page.nextReference != null)
                    BTN(
                      name: 'نمایش بیشتر',
                      disabled: _page.loading,
                      onTap: () => load(more: true),
                    ),
                ],
                BTN(
                  name: 'دریافت مجدد',
                  icon: IconsaxPlusLinear.refresh,
                  disabled: _page.loading,
                  onTap: load,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildPartyAccountRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return PartyAccountScreen(
    appId: args.required<String>('appId'),
    partyType: args.required<String>('partyType'),
    partyId: args.required<String>('partyId'),
  );
}
