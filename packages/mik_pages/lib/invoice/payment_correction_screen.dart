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
import 'package:mik_data/source/remote/models/invoice_payment.dart';
import 'package:mik_data/utils/fx/invoice_payment.dart';
import 'package:mik_utils/public/number.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class InvoicePaymentCorrectionScreen extends StatefulWidget {
  final InvoicePaymentFX fx;
  final String? paymentId, allocationId;
  final Future<bool> Function(InvoicePaymentCommand) send;
  const InvoicePaymentCorrectionScreen({
    required this.fx,
    required this.send,
    this.paymentId,
    this.allocationId,
    super.key,
  }) : assert((paymentId == null) != (allocationId == null));
  @override
  State<InvoicePaymentCorrectionScreen> createState() =>
      _InvoicePaymentCorrectionScreenState();
}

class _InvoicePaymentCorrectionScreenController extends GetxController {
  final reason = TextEditingController(), amount = TextEditingController();
  final confirmed = 'خیر'.obs;
  InvoicePaymentDetail? payment;
  InvoiceSettlementAllocation? allocation;
  List<InvoiceSettlementAllocation> linked = [];
  bool loading = true, saving = false, linksAvailable = false;
  String? error;
}

class _InvoicePaymentCorrectionScreenState
    extends State<InvoicePaymentCorrectionScreen> {
  late final _page = _InvoicePaymentCorrectionScreenController();

  bool get isPayment => widget.paymentId != null;
  bool get canEdit =>
      !_page.loading &&
      !_page.saving &&
      _page.error == null &&
      widget.fx.pending == null &&
      (isPayment
          ? widget.fx.canReversePayment &&
                _page.payment?.reversible == true &&
                _page.payment!.payment.branchId == widget.fx.branchId
          : widget.fx.canReverseAllocation &&
                _page.allocation?.invoiceId != null &&
                _page.allocation!.activeAmount > 0);
  String toman(int value) => '${Number.addCommas(value)} تومان';
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
    _page.amount.dispose();
    super.dispose();
  }

  Future<Object> load() async {
    if (_page.saving) return '';
    _page.confirmed.value = 'خیر';
    {
      _page.loading = true;
      _page.error = null;
      _page.payment = null;
      _page.allocation = null;
      _page.linked = [];
      _page.linksAvailable = false;
      _page.update();
    }
    try {
      await widget.fx.authorize();
      if (isPayment) {
        final row = await widget.fx.paymentDetail(widget.paymentId!);
        var allocations = <InvoiceSettlementAllocation>[];
        final canRead =
            widget.fx.canReadSources && widget.fx.canReadAllocations;
        if (canRead) {
          // Fully consumed/reversed sources still identify which allocations belong to this payment.
          final sources = await widget.fx.sources(availableOnly: false);
          final ids = sources
              .where(
                (s) => s.kind == 'PAYMENT' && s.referenceId == row.payment.id,
              )
              .map((s) => s.id)
              .toSet();
          allocations = (await widget.fx.allocations())
              .where(
                (a) =>
                    ids.contains(a.sourceId) ||
                    a.refundPaymentId == row.payment.id,
              )
              .toList();
        }
        if (mounted) {
          {
            _page.payment = row;
            _page.linked = allocations;
            _page.linksAvailable = canRead;
            _page.update();
          }
        }
      } else {
        final rows = await widget.fx.allocations();
        final found = rows
            .where((a) => a.id == widget.allocationId)
            .firstOrNull;
        final family = await widget.fx.invoiceDetails();
        if (found == null ||
            !family.documents.any((d) => d.id == found.invoiceId)) {
          throw const FormatException('Allocation not in invoice family');
        }
        if (mounted) {
          _page.allocation = found;
          _page.update();
        }
      }
    } catch (failure) {
      if (mounted) {
        _page.error = InvoicePaymentFX.message(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  Future<void> save() async {
    if (!canEdit) return;
    final text = _page.reason.text.trim();
    if (text.isEmpty ||
        text.length > 500 ||
        RegExp(r'[\u0000-\u0008]').hasMatch(text)) {
      Alert.error(
        'دلیل اصلاح را بین ۱ تا ۵۰۰ حرف وارد کنید.',
        context: context,
      );
      return;
    }
    late InvoicePaymentCommand command;
    if (isPayment) {
      if (_page.confirmed.value != 'بله') {
        Alert.error('ابتدا بازگشت واقعی وجه را تایید کنید.', context: context);
        return;
      }
      command = InvoicePaymentCommand('REVERSE_PAYMENT', {
        'paymentId': _page.payment!.payment.id,
        'expectedRevision': _page.payment!.revision,
        'reason': text,
        'fundsConfirmed': true,
      }, before: _page.payment!.json);
    } else {
      final value = int.tryParse(
        _page.amount.text.toEnglishDigit().replaceAll(',', '').trim(),
      );
      if (value == null ||
          value <= 0 ||
          value > _page.allocation!.activeAmount) {
        Alert.error(
          'مبلغ لغو باید مثبت و حداکثر برابر مبلغ فعال تخصیص باشد.',
          context: context,
        );
        return;
      }
      command = InvoicePaymentCommand('REVERSE_ALLOCATION', {
        'allocationId': _page.allocation!.id,
        'expectedRevision': _page.allocation!.revision,
        'amount': value,
        'reason': text,
      }, before: _page.allocation!.json);
    }
    {
      _page.saving = true;
      _page.update();
    }
    final success = await widget.send(command);
    if (!mounted) return;
    if (success || widget.fx.pending != null) {
      Get.back();
    } else {
      {
        _page.saving = false;
        _page.update();
      }
      await load();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_InvoicePaymentCorrectionScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(
          context,
          text: isPayment ? 'جزئیات و برگشت پرداخت' : 'لغو تخصیص اعتبار',
        ),
        child: (_) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            if (_page.error != null)
              Text(_page.error!, textAlign: TextAlign.center),
            MiniBTN(
              name: 'دریافت مجدد جزئیات',
              icon: IconsaxPlusLinear.refresh,
              noFlex: true,
              onTap: _page.loading || _page.saving ? null : load,
            ),
            if (_page.payment != null) ...[
              Text(
                '${_page.payment!.payment.direction == 'IN' ? 'دریافت' : 'پرداخت'}: ${toman(_page.payment!.payment.amount)}',
              ),
              SelectableText('شناسه پرداخت: ${_page.payment!.payment.id}'),
              Text(
                'وضعیت: ${_page.payment!.payment.status == 'CONFIRMED'
                    ? 'تاییدشده'
                    : _page.payment!.payment.status == 'REVERSED'
                    ? 'معکوس‌شده'
                    : _page.payment!.payment.status}',
              ),
              Text(
                'روش: ${const {'CASH': 'نقدی', 'CARD': 'کارت', 'BANK_TRANSFER': 'انتقال بانکی', 'CHEQUE': 'چک', 'ONLINE': 'آنلاین'}[_page.payment!.payment.method]}',
              ),
              if (_page.payment!.json['originalPaymentId'] is String)
                SelectableText(
                  'پرداخت اصلی: ${_page.payment!.json['originalPaymentId']}',
                ),
              if (_page.payment!.json['reversedByPaymentId'] is String)
                SelectableText(
                  'سند برگشت: ${_page.payment!.json['reversedByPaymentId']}',
                ),
              if (_page.payment!.reference != null)
                SelectableText('شماره پیگیری: ${_page.payment!.reference}'),
              if (_page.payment!.note != null)
                Text('توضیحات: ${_page.payment!.note}'),
              if (_page.payment!.routing?['fundName'] is String)
                Text('حساب: ${_page.payment!.routing!['fundName']}'),
              if (_page.payment!.routing?['terminalName'] is String)
                Text('کارت‌خوان: ${_page.payment!.routing!['terminalName']}'),
              MyDivider(text: 'تخصیص‌های این پرداخت در کسب‌وکار'),
              if (!_page.linksAvailable)
                const Text(
                  'برای مشاهدهٔ تخصیص‌ها، مجوز مشاهدهٔ حساب و تخصیص در سطح کسب‌وکار لازم است.',
                )
              else if (_page.linked.isEmpty)
                const Text('تخصیصی برای این پرداخت دریافت نشد.')
              else
                for (final row in _page.linked) ...[
                  if (row.invoiceId != null)
                    SelectableText('سند فاکتور: ${row.invoiceId}'),
                  if (row.refundPaymentId != null)
                    SelectableText('پرداخت عودت: ${row.refundPaymentId}'),
                  Text('مبلغ تخصیص: ${toman(row.amount)}'),
                  Text('مبلغ فعال: ${toman(row.activeAmount)}'),
                  Text('لغوشده: ${toman(row.reversedAmount)}'),
                  MyDivider(),
                ],
              MyDivider(text: 'برگشت پرداخت'),
              const Text(
                'این عملیات کل پرداخت را از مسیر مالی اصلی برمی‌گرداند و تخصیص‌های وابسته را اصلاح می‌کند؛ ممکن است ماندهٔ چند فاکتور تغییر کند.',
              ),
              if (!_page.payment!.reversible)
                const Text(
                  'برگشت در این مرحله برای پرداخت اصلی تاییدشدهٔ نسخهٔ جدید با روش نقد، کارت یا انتقال بانکی فعال است.',
                )
              else if (_page.payment!.payment.branchId != widget.fx.branchId)
                const Text(
                  'برای برگشت این پرداخت، شعبهٔ ثبت‌کنندهٔ آن را انتخاب کنید.',
                )
              else if (!widget.fx.canReversePayment)
                const Text(
                  'مجوز برگشت پرداخت، تخصیص یا استفاده از خزانه در این شعبه را ندارید.',
                ),
            ],
            if (_page.allocation != null) ...[
              SelectableText('شناسه تخصیص: ${_page.allocation!.id}'),
              SelectableText('سند فاکتور: ${_page.allocation!.invoiceId}'),
              Text('مبلغ فعال: ${toman(_page.allocation!.activeAmount)}'),
              Text('لغوشده: ${toman(_page.allocation!.reversedAmount)}'),
              const Text(
                'لغو تخصیص پولی جابه‌جا نمی‌کند؛ اعتبار طرف حساب آزاد می‌شود و بدهی فاکتور به همین میزان باز می‌شود.',
              ),
              if (!widget.fx.canReverseAllocation)
                const Text(
                  'مجوز لغو تخصیص در این شعبه و برگشت پرداخت در کسب‌وکار لازم است.',
                ),
              if (_page.allocation!.activeAmount == 0)
                const Text('این تخصیص مبلغ فعالی برای لغو ندارد.'),
            ],
            if (canEdit || _page.saving) ...[
              if (!isPayment)
                Input(
                  key: const ValueKey('reverse-allocation-amount'),
                  controller: _page.amount,
                  name: 'مبلغ لغو تخصیص (تومان)',
                  require: true,
                  keyboardType: TextInputType.number,
                  readOnly: _page.saving,
                ),
              Input(
                key: const ValueKey('correction-reason'),
                controller: _page.reason,
                name: 'دلیل اصلاح',
                require: true,
                maxLength: 500,
                readOnly: _page.saving,
              ),
              if (isPayment) ...[
                const Text('آیا وجه واقعاً از مسیر اصلی بازگردانده شده است؟'),
                IgnorePointer(
                  ignoring: _page.saving,
                  child: MyTab(
                    tab: const ['خیر', 'بله'],
                    value: _page.confirmed,
                    callback: (String v) => _page.confirmed.value = v,
                  ),
                ),
              ],
              BTN(
                name: isPayment ? 'ثبت برگشت پرداخت' : 'ثبت لغو تخصیص',
                disabled: _page.saving,
                onTap: save,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget buildInvoicePaymentCorrectionRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return InvoicePaymentCorrectionScreen(
    fx: args.required<InvoicePaymentFX>('fx'),
    send: args.required<Future<bool> Function(InvoicePaymentCommand)>('send'),
    paymentId: args.optional<String>('paymentId'),
    allocationId: args.optional<String>('allocationId'),
  );
}
