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
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/invoice_payment.dart';
import 'package:mik_data/source/remote/models/invoice_read.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/invoice_payment.dart';
import 'package:mik_data/utils/fx/sale_invoice.dart';
import 'package:mik_utils/public/number.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class InvoicePaymentScreen extends StatefulWidget {
  final String appId;
  final RemoteInvoiceSummary invoice;
  const InvoicePaymentScreen({
    required this.appId,
    required this.invoice,
    super.key,
  });
  @override
  State<InvoicePaymentScreen> createState() => _InvoicePaymentScreenState();
}

class _InvoicePaymentScreenController extends GetxController {
  final method = 'نقدی'.obs, confirmed = 'بله'.obs, paymentMode = 'ثبت وجه'.obs;
  final amount = TextEditingController(),
      reference = TextEditingController(),
      note = TextEditingController(),
      allocationAmount = TextEditingController();
  InvoicePaymentFX? fx;
  RemoteInvoiceDetail? detail;
  List<InvoicePartyPayment> payments = [];
  List<InvoiceSettlementSource> sources = [];
  List<InvoiceSettlementDocument> documents = [];
  List<SalePaymentTarget> targets = [];
  List<InvoiceSettlementAllocation> allocations = [];
  String? targetId, sourceId, documentId, error;
  bool loading = true, saving = false, anonymous = false;
  int generation = 0;
}

class _InvoicePaymentScreenState extends State<InvoicePaymentScreen> {
  late final _page = _InvoicePaymentScreenController();

  static const methods = {
    'نقدی': 'CASH',
    'کارت': 'CARD',
    'انتقال بانکی': 'BANK_TRANSFER',
  };
  static const methodNames = {
    'CASH': 'نقدی',
    'CARD': 'کارت',
    'BANK_TRANSFER': 'انتقال بانکی',
    'CHEQUE': 'چک',
    'ONLINE': 'آنلاین',
  };
  static const paymentStatuses = {
    'PENDING': 'در انتظار',
    'CONFIRMED': 'تاییدشده',
    'BOUNCED': 'برگشتی',
    'RETURNED': 'عودت‌شده',
    'REVERSED': 'معکوس‌شده',
  };

  bool get refund => _page.paymentMode.value == 'برگشت وجه';
  String get actualDirection =>
      refund ? _page.fx!.refundDirection : _page.fx!.direction;
  int get refundable =>
      _page.sources.fold<int>(0, (sum, row) => sum + row.available);

  bool get locked =>
      _page.loading ||
      _page.saving ||
      _page.error != null ||
      _page.fx?.pending != null;
  bool get active =>
      (_page.detail?.summary.status == 'ISSUED' ||
          refund && _page.detail?.summary.status == 'CANCELLED') &&
      _page.detail?.summary.paymentApplicable == true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    _page.generation++;
    for (final c in [
      _page.amount,
      _page.reference,
      _page.note,
      _page.allocationAmount,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void fail(Object failure) {
    _page.error = InvoicePaymentFX.message(failure);
    Alert.error(_page.error!, context: context);
  }

  Future<Object> load() async {
    if (_page.saving) return '';
    final request = ++_page.generation;
    {
      _page.loading = true;
      _page.error = null;
      _page.detail = null;
      _page.payments = [];
      _page.allocations = [];
      _page.sources = [];
      _page.documents = [];
      _page.targets = [];
      _page.targetId = null;
      _page.sourceId = null;
      _page.documentId = null;
      _page.update();
    }
    try {
      final context = BusinessContext.forApp(widget.appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= InvoicePaymentFX(context, widget.invoice);
      await _page.fx!.restore();
      await _page.fx!.authorize();
      final invoice = await _page.fx!.invoiceDetails();
      final rows = _page.fx!.canReadPayments
          ? await _page.fx!.payments()
          : <InvoicePartyPayment>[];
      final credits = _page.fx!.canReadSources
          ? await _page.fx!.sources()
          : <InvoiceSettlementSource>[];
      final allAllocations = _page.fx!.canReadAllocations
          ? await _page.fx!.allocations()
          : <InvoiceSettlementAllocation>[];
      final familyIds = invoice.documents.map((d) => d.id).toSet();
      final destinations =
          (refund
                  ? _page.fx!.canRefund && _page.fx!.canReadSources
                  : _page.fx!.canCreate) &&
              (!invoice.anonymous || refund) &&
              (invoice.detail.summary.status == 'ISSUED' ||
                  refund && invoice.detail.summary.status == 'CANCELLED') &&
              _page.fx!.pending == null
          ? await _page.fx!.targets(
              methods[_page.method.value]!,
              refund: refund,
            )
          : <SalePaymentTarget>[];
      if (!mounted || request != _page.generation) return '';
      {
        _page.detail = invoice.detail;
        _page.anonymous = invoice.anonymous;
        _page.documents = invoice.documents
            .where((r) => r.status == 'ISSUED' && r.remaining > 0)
            .toList();
        _page.payments = rows;
        _page.allocations = allAllocations
            .where((a) => familyIds.contains(a.invoiceId))
            .toList();
        _page.sources = invoice.anonymous
            ? credits
                  .where((row) => row.restrictedRootId == widget.invoice.rootId)
                  .toList()
            : credits;
        _page.targets = destinations;
        _page.update();
      }
    } catch (failure) {
      if (mounted && request == _page.generation) fail(failure);
    } finally {
      if (mounted && request == _page.generation) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  Future<void> changeMethod(String value) async {
    if (locked) return;
    _page.method.value = value;
    _page.confirmed.value = 'بله';
    {
      _page.loading = true;
      _page.targetId = null;
      _page.targets = [];
      _page.update();
    }
    try {
      final result = await _page.fx!.targets(methods[value]!, refund: refund);
      if (mounted) {
        _page.targets = result;
        _page.update();
      }
    } catch (failure) {
      if (mounted) fail(failure);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  // Accounting amounts are always integer tomans, independent of legacy display settings.
  String toman(int value) => '${Number.addCommas(value)} تومان';

  int? money(String value) =>
      int.tryParse(value.toEnglishDigit().replaceAll(',', '').trim());
  Future<void> create() async {
    if (locked) return;
    final value = money(_page.amount.text);
    if (value == null ||
        value <= 0 ||
        value > 9007199254740991 ||
        _page.confirmed.value != 'بله' ||
        !_page.targets.any((t) => t.id == _page.targetId)) {
      Alert.error('مبلغ مثبت و حساب مقصد یا مبدأ لازم است.', context: context);
      return;
    }
    if (refund && (!_page.fx!.canReadSources || value > refundable)) {
      Alert.error(
        'مبلغ برگشت از اعتبار آزاد طرف حساب بیشتر است.',
        context: context,
      );
      return;
    }
    final ref = _page.reference.text.trim(), text = _page.note.text.trim();
    if (ref.length > 200 ||
        text.length > 1000 ||
        RegExp(r'[\u0000-\u0008]').hasMatch('$ref$text')) {
      Alert.error('شماره پیگیری یا توضیحات معتبر نیست.', context: context);
      return;
    }
    final target = _page.targets.firstWhere((t) => t.id == _page.targetId);
    await send(
      InvoicePaymentCommand(refund ? 'REFUND' : 'PAYMENT', {
        'partyType': widget.invoice.partyType,
        'partyId': widget.invoice.partyId,
        if (refund && _page.anonymous) 'rootInvoiceId': widget.invoice.rootId,
        'payment': {
          'amount': value,
          'direction': actualDirection,
          'method': methods[_page.method.value],
          'confirmed': true,
          'routing': target.routing,
          if (ref.isNotEmpty) 'transactionReference': ref,
          if (text.isNotEmpty) 'note': text,
        },
      }),
    );
  }

  Future<void> allocate() async {
    if (locked) return;
    final value = money(_page.allocationAmount.text);
    final chosen = _page.sources
        .where((s) => s.id == _page.sourceId)
        .firstOrNull;
    final doc = _page.documents
        .where((d) => d.id == _page.documentId)
        .firstOrNull;
    if (chosen == null ||
        doc == null ||
        value == null ||
        value <= 0 ||
        value > chosen.available ||
        value > doc.remaining) {
      Alert.error(
        'اعتبار، سند و مبلغ متناسب با اعتبار قابل استفاده و ماندهٔ سند را انتخاب کنید.',
        context: context,
      );
      return;
    }
    await send(
      InvoicePaymentCommand('ALLOCATE', {
        'sourceId': chosen.id,
        'invoiceId': doc.id,
        'amount': value,
      }),
    );
  }

  Future<bool> send(InvoicePaymentCommand command) async {
    if (_page.saving || _page.fx == null) return false;
    {
      _page.saving = true;
      _page.error = null;
      _page.update();
    }
    var success = false;
    try {
      await _page.fx!.send(command);
      if (!mounted) return false;
      success = true;
      Alert.success(switch (command.action) {
        'PAYMENT' =>
          'وجه با موفقیت ثبت شد؛ وضعیت تخصیص و ماندهٔ فاکتور را بررسی کنید.',
        'REFUND' => 'برگشت جزئی وجه با موفقیت ثبت شد.',
        'REVERSE_PAYMENT' => 'برگشت پرداخت با موفقیت ثبت شد.',
        'REVERSE_ALLOCATION' => 'لغو تخصیص با موفقیت ثبت شد.',
        _ => 'اعتبار با موفقیت به سند فاکتور تخصیص یافت.',
      });
      if (['PAYMENT', 'REFUND'].contains(command.action)) {
        _page.amount.clear();
        _page.reference.clear();
        _page.note.clear();
        _page.confirmed.value = 'بله';
      } else {
        _page.allocationAmount.clear();
      }
    } catch (failure) {
      if (mounted) fail(failure);
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
    if (success && mounted) await load();
    return success;
  }

  Future<void> correction({String? paymentId, String? allocationId}) async {
    if (locked || _page.fx == null) return;
    await Get.toNamed(
      nav_routes.RoutesName.INVOICE_PAYMENT_CORRECTION,
      arguments: {
        'fx': _page.fx!,
        'paymentId': paymentId,
        'allocationId': allocationId,
        'send': send,
      },
      preventDuplicates: false,
    );
    if (mounted) await load();
  }

  Widget choice(String label, bool selected, VoidCallback onTap) => MiniBTN(
    name: '${selected ? '✓ ' : ''}$label',
    icon: IconsaxPlusLinear.tick_circle,
    noFlex: true,
    onTap: locked ? null : onTap,
  );
  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_InvoicePaymentScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(
          context,
          text: 'دریافت‌وپرداخت فاکتور ${widget.invoice.number}',
        ),
        child: (_) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            if (_page.error != null)
              Text(_page.error!, textAlign: TextAlign.center),
            MiniBTN(
              name: 'دریافت مجدد',
              icon: IconsaxPlusLinear.refresh,
              noFlex: true,
              onTap: _page.loading || _page.saving ? null : load,
            ),
            if (_page.fx?.pending != null) ...[
              const Text(
                'نتیجهٔ درخواست قبلی مشخص نیست؛ برای جلوگیری از ثبت تکراری، همان درخواست را پیگیری کنید.',
              ),
              BTN(
                name: 'پیگیری درخواست قبلی',
                disabled: _page.loading || _page.saving,
                onTap: () => send(_page.fx!.pending!),
              ),
            ],
            if (_page.detail != null) ...[
              Text(
                _page.detail!.summary.partyName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('ماندهٔ فاکتور: ${toman(_page.detail!.summary.openAmount)}'),
              Text('تسویه‌شده: ${toman(_page.detail!.settledAmount)}'),
              IgnorePointer(
                ignoring: locked,
                child: MyTab(
                  tab: const ['ثبت وجه', 'برگشت وجه'],
                  value: _page.paymentMode,
                  callback: (String value) {
                    _page.paymentMode.value = value;
                    _page.confirmed.value = 'بله';
                    _page.amount.clear();
                    load();
                  },
                ),
              ),
              if (refund)
                Text(
                  _page.anonymous
                      ? 'اعتبار آزاد همین فاکتور: ${toman(refundable)}'
                      : 'اعتبار آزاد کل حساب طرف حساب: ${toman(refundable)}؛ برگشت از این اعتبار مصرف می‌شود.',
                ),
              if (active) ...[
                MyDivider(
                  text: refund
                      ? 'ثبت برگشت جزئی وجه'
                      : _page.fx!.direction == 'IN'
                      ? 'ثبت دریافت از مشتری'
                      : 'ثبت پرداخت به تأمین‌کننده',
                ),
                Text(
                  refund
                      ? 'مبلغ برگشتی از اعتبار آزاد کم می‌شود؛ آن را پس از جابه‌جایی واقعی وجه ثبت کنید.'
                      : 'ثبت وجه در حساب طرف حساب انجام می‌شود. سرور طبق سیاست کسب‌وکار آن را بین فاکتورها تخصیص می‌دهد؛ برای تخصیص دستی از اعتبار قابل استفادهٔ پایین صفحه استفاده کنید.',
                ),
                if (_page.anonymous && !refund)
                  const Text(
                    'مشتری پیش‌فرض امکان ثبت وجه مستقل ندارد؛ پرداخت آن باید در جریان خود فاکتور انجام شود.',
                  )
                else if (refund
                    ? _page.fx!.canRefund && _page.fx!.canReadSources
                    : _page.fx!.canCreate) ...[
                  IgnorePointer(
                    ignoring: locked,
                    child: MyTab(
                      tab: methods.keys.toList(),
                      value: _page.method,
                      callback: changeMethod,
                    ),
                  ),
                  MyDivider(
                    text: actualDirection == 'IN'
                        ? 'حساب دریافت وجه'
                        : 'حساب پرداخت وجه',
                  ),
                  if (_page.targets.isEmpty && !_page.loading)
                    const Text(
                      'حساب یا صندوق مجازی برای این روش دریافت نشد. تعریف حساب و مجوز استفاده را بررسی کنید.',
                    ),
                  for (final target in _page.targets)
                    choice(target.name, _page.targetId == target.id, () {
                      _page.targetId = target.id;
                      _page.update();
                    }),
                  Input(
                    key: const ValueKey('payment-amount'),
                    controller: _page.amount,
                    name: 'مبلغ (تومان)',
                    require: true,
                    keyboardType: TextInputType.number,
                    readOnly: locked,
                  ),
                  Input(
                    controller: _page.reference,
                    name: 'شماره پیگیری',
                    maxLength: 200,
                    readOnly: locked,
                  ),
                  Input(
                    controller: _page.note,
                    name: 'توضیحات',
                    maxLength: 1000,
                    readOnly: locked,
                  ),
                  BTN(
                    name: refund
                        ? 'ثبت برگشت وجه'
                        : _page.fx!.direction == 'IN'
                        ? 'ثبت دریافت وجه'
                        : 'ثبت پرداخت وجه',
                    disabled: locked,
                    onTap: create,
                  ),
                ] else
                  const Text(
                    'مجوز ثبت وجه و تخصیص در این شعبه یا استفاده از خزانه را ندارید.',
                  ),
                MyDivider(text: 'تخصیص اعتبار به همین فاکتور'),
                if (!_page.fx!.canAllocate)
                  const Text(
                    'برای مشاهده و تخصیص اعتبار، مجوز مشاهدهٔ حساب طرف حساب و تخصیص در شعبه لازم است.',
                  )
                else if (_page.sources.isEmpty)
                  const Text(
                    'اعتبار قابل استفاده‌ای برای این فاکتور وجود ندارد.',
                  )
                else if (_page.documents.isEmpty)
                  const Text('فاکتور سند بدهکار با ماندهٔ قابل تسویه ندارد.')
                else ...[
                  for (final (index, source) in _page.sources.indexed)
                    choice(
                      '${source.kind == 'PAYMENT' ? 'وجه ثبت‌شده' : 'اعتبار اصلاحی'} ${index + 1}: ${toman(source.available)}',
                      _page.sourceId == source.id,
                      () {
                        _page.sourceId = source.id;
                        _page.update();
                      },
                    ),
                  MyDivider(text: 'سند بدهکار فاکتور'),
                  for (final doc in _page.documents)
                    choice(
                      '${doc.number}: ${toman(doc.remaining)}',
                      _page.documentId == doc.id,
                      () {
                        _page.documentId = doc.id;
                        _page.update();
                      },
                    ),
                  Input(
                    key: const ValueKey('allocation-amount'),
                    controller: _page.allocationAmount,
                    name: 'مبلغ تخصیص (تومان)',
                    require: true,
                    keyboardType: TextInputType.number,
                    readOnly: locked,
                  ),
                  BTN(name: 'تخصیص اعتبار', disabled: locked, onTap: allocate),
                ],
              ] else
                const Text(
                  'ثبت وجه و تخصیص در این صفحه برای فاکتور ثبت‌شدهٔ خرید یا فروش فعال است.',
                ),
              MyDivider(text: 'تخصیص‌های این فاکتور'),
              if (_page.fx!.canReadAllocations) ...[
                if (_page.allocations.isEmpty)
                  const Text('تخصیصی برای اسناد این فاکتور ثبت نشده است.'),
                for (final row in _page.allocations) ...[
                  SelectableText('سند فاکتور: ${row.invoiceId}'),
                  Text('مبلغ فعال تخصیص: ${toman(row.activeAmount)}'),
                  Text('لغوشده: ${toman(row.reversedAmount)}'),
                  if (_page.fx!.canReverseAllocation && row.activeAmount > 0)
                    MiniBTN(
                      name: 'لغو تخصیص',
                      icon: IconsaxPlusLinear.edit_2,
                      noFlex: true,
                      onTap: locked
                          ? null
                          : () => correction(allocationId: row.id),
                    ),
                  MyDivider(),
                ],
              ] else
                const Text('مجوز مشاهدهٔ تخصیص‌ها در سطح کسب‌وکار را ندارید.'),
              BTN(
                name: 'چک‌های طرف حساب',
                navigate: true,
                disabled: _page.loading || _page.saving,
                onTap: () async {
                  await Get.toNamed(
                    nav_routes.RoutesName.REMOTE_CHEQUE,
                    arguments: {
                      'appId': widget.appId,
                      'invoice': widget.invoice,
                    },
                    preventDuplicates: false,
                  );
                  if (mounted) await load();
                },
              ),
              MyDivider(text: 'وجوه طرف حساب در کل کسب‌وکار'),
              const Text(
                'این فهرست همهٔ وجوه طرف حساب را نشان می‌دهد و مختص این فاکتور نیست.',
              ),
              if (!_page.fx!.canReadPayments)
                const Text('مجوز مشاهدهٔ فهرست وجوه را ندارید.')
              else if (_page.payments.isEmpty)
                const Text('وجهی ثبت نشده است.')
              else
                for (final row in _page.payments)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row.direction == 'IN' ? 'دریافت' : 'پرداخت'} ${methodNames[row.method]} — ${toman(row.amount)}',
                      ),
                      Text(paymentStatuses[row.status]!),
                      SelectableText('شناسه پرداخت: ${row.id}'),
                      MiniBTN(
                        name: 'جزئیات پرداخت',
                        icon: IconsaxPlusLinear.info_circle,
                        noFlex: true,
                        onTap: locked
                            ? null
                            : () => correction(paymentId: row.id),
                      ),
                      MyDivider(),
                    ],
                  ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget buildInvoicePaymentRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return InvoicePaymentScreen(
    appId: args.required<String>('appId'),
    invoice: args.required<RemoteInvoiceSummary>('invoice'),
  );
}
