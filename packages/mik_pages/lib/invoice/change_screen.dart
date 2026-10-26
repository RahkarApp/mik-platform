import 'package:mik_router/mik_router.dart' as nav_routes;

import 'dart:async';

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
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/inventory_quantity.dart';
import 'package:mik_data/source/remote/models/invoice_read.dart';
import 'package:mik_data/source/remote/models/remote_json.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/invoice_change.dart';
import 'package:mik_data/utils/fx/sale_invoice.dart';
import 'package:mik_utils/public/price.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class InvoiceChangeScreen extends StatefulWidget {
  final String appId;
  final RemoteInvoiceSummary invoice;
  final bool delivery;
  const InvoiceChangeScreen({
    required this.appId,
    required this.invoice,
    this.delivery = false,
    super.key,
  });
  @override
  State<InvoiceChangeScreen> createState() => _InvoiceChangeScreenState();
}

class _InvoiceChangeScreenController extends GetxController {
  final deliveryStatus = 'انتخاب نشده'.obs;
  final action = 'ویرایش'.obs;
  final conversionConfirmed = 'خیر'.obs;
  final conversionPayment = 'بدون دریافت وجه'.obs;
  String conversionMethod = 'CASH';
  List<SalePaymentTarget> conversionTargets = [];
  SalePaymentTarget? conversionTarget;
  bool targetsLoading = false;
  final reason = TextEditingController();
  final quantities = <String, TextEditingController>{},
      prices = <String, TextEditingController>{},
      discounts = <String, TextEditingController>{},
      returns = <String, TextEditingController>{};
  final totals = {
    for (final key in _InvoiceChangeScreenState.totalNames.keys)
      key: TextEditingController(),
  };
  final added = <Map<String, dynamic>>[];
  final conditions = <String, RxString>{};
  InvoiceChangeFX? fx;
  InvoiceChangeSnapshot? current;
  bool loading = true, saving = false;
  String? error;
  Timer? timer;
}

class _InvoiceChangeScreenState extends State<InvoiceChangeScreen> {
  late final _page = _InvoiceChangeScreenController();

  Map<String, String> get actions => widget.invoice.type == 'PROFORMA'
      ? {'ویرایش': 'amend', 'تبدیل به فروش': 'convert', 'لغو': 'cancel'}
      : {
          'ویرایش': 'amend',
          if (widget.invoice.type == 'SALE') 'تحویل': 'status',
          'مرجوعی': 'return',
          'لغو': 'cancel',
        };
  static const deliveries = {
    'PENDING': 'در انتظار',
    'READY': 'آماده',
    'SHIPPED': 'ارسال‌شده',
    'DELIVERED': 'تحویل‌شده',
  };

  List<String> get deliveryOptions => _page.current == null
      ? []
      : deliveries.keys
            .where((s) => _page.fx!.canDeliver(_page.current!, s))
            .toList();
  static const totalNames = {
    'discountAmount': 'تخفیف فاکتور (تومان)',
    'shippingAmount': 'هزینه ارسال (تومان)',
    'surchargeAmount': 'سایر هزینه‌ها (تومان)',
    'taxAmount': 'مالیات (تومان)',
  };

  Future<void> loadConversionTargets() async {
    if (locked || _page.targetsLoading) return;
    {
      _page.targetsLoading = true;
      _page.conversionTargets = [];
      _page.conversionTarget = null;
      _page.update();
    }
    try {
      final service = SaleInvoiceFX(context: _page.fx!.context);
      await service.authorize();
      final rows = await service.paymentTargets(_page.conversionMethod);
      if (mounted) {
        _page.conversionTargets = rows;
        _page.update();
      }
      if (rows.isEmpty && mounted) {
        Alert.error('مقصد فعال برای دریافت وجه وجود ندارد.', context: context);
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(SaleInvoiceFX.message(failure), context: context);
      }
    } finally {
      if (mounted) {
        _page.targetsLoading = false;
        _page.update();
      }
    }
  }

  List<Map<String, dynamic>> get editableLines => [
    ..._page.current!.lines,
    ..._page.added,
  ];

  bool get locked =>
      _page.loading ||
      _page.saving ||
      _page.fx?.pending != null ||
      _page.error != null;
  String get mode => actions[_page.action.value]!;
  bool allowed(String value) =>
      _page.current != null &&
      _page.current!.detail.summary.status == 'ISSUED' &&
      _page.fx!.allowed(value) &&
      _page.fx!.own(_page.current!, value) &&
      (value != 'status' || deliveryOptions.isNotEmpty) &&
      (value != 'convert' ||
          _page.current!.detail.convertedInvoiceId == null &&
              (_page.current!.detail.validUntil == null ||
                  _page.current!.detail.validUntil!.isAfter(DateTime.now()))) &&
      _page.current!.detail.summary.operationId == null &&
      (value != 'return' || _page.current!.posted) &&
      (value != 'cancel' ||
          !_page.current!.posted ||
          widget.invoice.type == 'PURCHASE') &&
      (value != 'amend' ||
          _page.current!.detail.summary.deliveryStatus != 'SHIPPED');
  @override
  void initState() {
    super.initState();
    if (widget.delivery) _page.action.value = 'تحویل';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  void clearInputs() {
    for (final group in [
      _page.quantities,
      _page.prices,
      _page.discounts,
      _page.returns,
    ]) {
      for (final c in group.values) {
        c.dispose();
      }
      group.clear();
    }
    _page.conditions.clear();
    _page.added.clear();
  }

  @override
  void dispose() {
    _page.timer?.cancel();
    clearInputs();
    _page.reason.dispose();
    for (final c in _page.totals.values) {
      c.dispose();
    }
    super.dispose();
  }

  void apply(InvoiceChangeSnapshot row) {
    clearInputs();
    _page.current = row;
    _page.deliveryStatus.value = 'انتخاب نشده';
    for (final line in row.lines) {
      final data = RemoteJson(line), id = data.text('lineId');
      _page.quantities[id] = TextEditingController(text: data.text('quantity'));
      _page.prices[id] = TextEditingController(
        text: '${data.number('unitPrice')}',
      );
      _page.discounts[id] = TextEditingController(
        text: '${data.number('discountAmount')}',
      );
      _page.returns[id] = TextEditingController();
      _page.conditions[id] = 'انتخاب نشده'.obs;
    }
    for (final key in _page.totals.keys) {
      _page.totals[key]!.text = '${row.detail.totals[key]}';
    }
  }

  void fail(Object failure) {
    _page.error = InvoiceChangeFX.message(failure);
    Alert.error(_page.error!, context: context);
  }

  Future<Object> load() async {
    if (_page.saving) return '';
    _page.timer?.cancel();
    {
      _page.loading = true;
      _page.error = null;
      _page.update();
    }
    try {
      final context = BusinessContext.forApp(widget.appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= InvoiceChangeFX(context, widget.invoice);
      await _page.fx!.restore();
      final row = await _page.fx!.load();
      if (!mounted) return '';
      {
        apply(row);
        _page.update();
      }
      if (_page.fx!.pending != null) {
        await track();
      }
    } catch (failure) {
      if (mounted) fail(failure);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  String decimal(String value) =>
      value.toEnglishDigit().replaceAll(',', '').trim();
  int money(String value) {
    final number = int.tryParse(decimal(value));
    return RemoteInvoiceSummary.money(number);
  }

  Future<void> addProduct() async {
    if (locked || !allowed('amend')) return;
    if (editableLines.length >= 30) {
      Alert.error(
        'حداکثر ۳۰ تنوع در هر فاکتور قابل ثبت است.',
        context: context,
      );
      return;
    }
    final Map<String, dynamic>? row = await Get.toNamed<dynamic>(
      nav_routes.RoutesName.INVOICE_CHANGE_PRODUCT_PICKER,
      arguments: {
        'fx': _page.fx!,
        'existing': editableLines.map((r) => r['variantId'] as String).toSet(),
      },
      preventDuplicates: false,
    );
    if (!mounted || row == null) return;
    try {
      _page.fx!.check();
      final id = row['lineId'] as String;
      {
        _page.added.add(row);
        _page.quantities[id] = TextEditingController(text: '1');
        _page.prices[id] = TextEditingController(
          text: row['unitPrice']?.toString() ?? '',
        );
        _page.discounts[id] = TextEditingController(text: '0');
        _page.returns[id] = TextEditingController();
        _page.conditions[id] = 'انتخاب نشده'.obs;
        _page.update();
      }
    } catch (failure) {
      fail(failure);
    }
  }

  Future<void> submit() async {
    if (locked || _page.targetsLoading || !allowed(mode)) return;
    if (mode == 'status') {
      final selected = deliveries.entries
          .where((e) => e.value == _page.deliveryStatus.value)
          .firstOrNull
          ?.key;
      final text = _page.reason.text.trim();
      if (selected == null || !_page.fx!.canDeliver(_page.current!, selected)) {
        Alert.error('وضعیت مجاز تحویل را انتخاب کنید.', context: context);
        return;
      }
      if (text.isEmpty || text.length > 500) {
        Alert.error(
          'دلیل تغییر وضعیت را وارد کنید (حداکثر ۵۰۰ کاراکتر).',
          context: context,
        );
        return;
      }
      {
        _page.saving = true;
        _page.error = null;
        _page.update();
      }
      try {
        // Confirmation is local: the API accepts only status/revision/reason.
        await _page.fx!.send(
          InvoiceChangeCommand('status', {
            'invoiceId': widget.invoice.id,
            'expectedRevision': _page.current!.revision,
            'status': selected,
            'reason': text,
          }),
        );
        await handle();
      } catch (failure) {
        if (mounted) {
          fail(failure);
          _page.update();
        }
      } finally {
        if (mounted) {
          _page.saving = false;
          _page.update();
        }
      }
      return;
    }
    if (mode == 'convert') {
      if (_page.conversionConfirmed.value != 'بله') {
        Alert.error(
          'تبدیل به فروش و رزرو موجودی را تأیید کنید.',
          context: context,
        );
        return;
      }
      Map<String, Object>? payment;
      if (_page.conversionPayment.value == 'دریافت کامل' &&
          _page.current!.detail.summary.total > 0) {
        final target = _page.conversionTarget;
        if (target == null) {
          Alert.error('مقصد دریافت وجه را انتخاب کنید.', context: context);
          return;
        }
        final service = SaleInvoiceFX(context: _page.fx!.context);
        {
          _page.saving = true;
          _page.update();
        }
        try {
          await service.authorize();
          final rows = await service.paymentTargets(_page.conversionMethod);
          if (!rows.any((r) => r.id == target.id)) {
            throw const AuthError(409, 'PAYMENT_TARGET_CHANGED');
          }
          payment = {
            'method': _page.conversionMethod,
            'direction': 'IN',
            'amount': _page.current!.detail.summary.total,
            'confirmed': true,
            'routing': target.routing,
          };
        } catch (failure) {
          if (mounted) {
            {
              _page.saving = false;
              _page.update();
            }
            Alert.error(SaleInvoiceFX.message(failure), context: context);
          }
          return;
        }
      }
      if (!mounted) return;
      {
        _page.saving = true;
        _page.error = null;
        _page.update();
      }
      try {
        await _page.fx!.send(
          InvoiceChangeCommand('convert', {
            'invoiceId': widget.invoice.id,
            'expectedRevision': _page.current!.revision,
            'type': 'SALE',
            'deliveryStatus': 'PENDING',
            if (payment != null) 'payments': [payment],
          }),
        );
        await handle();
      } catch (failure) {
        if (mounted) {
          fail(failure);
          _page.update();
        }
      } finally {
        if (mounted) {
          _page.saving = false;
          _page.update();
        }
      }
      return;
    }
    try {
      final text = _page.reason.text.trim();
      if (text.isEmpty ||
          text.length > 500 ||
          RegExp(r'[\u0000-\u0008]').hasMatch(text)) {
        throw const FormatException('reason');
      }
      final body = <String, dynamic>{
        'invoiceId': widget.invoice.id,
        'expectedRevision': _page.current!.revision,
        'reason': text,
      };
      final cond = <Map<String, String>>[], rows = <Map<String, dynamic>>[];
      var physical = false;
      for (final line
          in mode == 'amend' ? editableLines : _page.current!.lines) {
        final data = RemoteJson(line), id = data.text('lineId');
        final newLine = _page.added.any((r) => r['lineId'] == id);
        final old = newLine
            ? BigInt.zero
            : InvoiceChangeFX.units(data.text('quantity'));
        BigInt count;
        if (mode == 'amend') {
          final value = InventoryQuantity.fromJson(
            decimal(_page.quantities[id]!.text),
          ).toString();
          count = InvoiceChangeFX.units(value);
          if (count > BigInt.zero) {
            rows.add({
              'lineId': id,
              'variantId': data.text('variantId'),
              'quantity': value,
              if (data.optionalText('productPriceId') != null)
                'productPriceId': data.text('productPriceId'),
              'unitPrice': money(_page.prices[id]!.text),
              'discountAmount': money(_page.discounts[id]!.text),
              if (data.value['warehouseIds'] != null)
                'warehouseIds': data.strings('warehouseIds'),
            });
          }
          if (_page.current!.posted && count != old) physical = true;
        } else if (mode == 'return') {
          final value = _page.returns[id]!.text.trim().isEmpty
              ? '0'
              : decimal(_page.returns[id]!.text);
          count = InvoiceChangeFX.units(value);
          if (count > old) {
            throw const FormatException('return exceeds quantity');
          }
          if (count > BigInt.zero) {
            rows.add({
              'lineId': id,
              'quantity': InventoryQuantity.fromJson(value).toString(),
            });
            physical = true;
          }
        } else {
          count = old;
          if (_page.current!.posted) physical = true;
        }
        final conditionRequired =
            _page.current!.posted &&
            (mode == 'cancel' ||
                mode == 'return' && count > BigInt.zero ||
                mode == 'amend' && count < old);
        if (conditionRequired) {
          final value = _page.conditions[id]!.value;
          if (value == 'انتخاب نشده') {
            throw const FormatException('condition required');
          }
          cond.add({
            'lineId': id,
            'condition': value == 'سالم' ? 'SELLABLE' : 'DAMAGED',
          });
        }
      }
      if (mode == 'amend') {
        if (rows.isEmpty) throw const FormatException('empty invoice');
        body['lines'] = rows;
        for (final key in _page.totals.keys) {
          body[key] = money(_page.totals[key]!.text);
        }
      } else if (mode == 'return') {
        if (rows.isEmpty) throw const FormatException('empty return');
        body['lines'] = rows;
      }
      if (physical) body['goodsConfirmed'] = true;
      if (cond.isNotEmpty) body['conditions'] = cond;
      {
        _page.saving = true;
        _page.error = null;
        _page.update();
      }
      try {
        await _page.fx!.send(InvoiceChangeCommand(mode, body));
        await handle();
      } finally {
        if (mounted) {
          _page.saving = false;
          _page.update();
        }
      }
    } catch (failure) {
      if (!mounted) return;
      if (failure is FormatException && _page.fx?.pending == null) {
        Alert.error(
          'دلیل، تعداد و مبالغ را بررسی کنید؛ وضعیت کالای برگشتی لازم است.',
          context: context,
        );
      } else {
        {
          fail(failure);
          _page.update();
        }
      }
    }
  }

  Future<void> handle() async {
    if (!mounted || _page.fx!.pending == null) return;
    final op = _page.fx!.pending!.operation;
    if (op == null) return;
    final status = op['status'];
    if (status == 'SUCCEEDED' || status == 'FAILED') {
      final failure = op['errorCode'] as String?;
      final result = await _page.fx!.finish();
      if (!mounted) return;
      {
        apply(result);
        _page.error = null;
        _page.update();
      }
      if (status == 'SUCCEEDED') {
        _page.reason.clear();
        Alert.success('عملیات فاکتور با موفقیت تکمیل شد.');
      } else {
        fail(AuthError(409, failure ?? 'OPERATION_FAILED'));
      }
    } else if (status == 'ACTION_REQUIRED') {
      Alert.error(
        'پردازش فاکتور به پیگیری نیاز دارد؛ عملیات جدید ثبت نکنید و همان درخواست را بازیابی کنید.',
        context: context,
      );
    } else {
      _page.timer?.cancel();
      _page.timer = Timer(const Duration(seconds: 2), () {
        if (mounted) track();
      });
    }
  }

  Future<void> track({bool retry = false}) async {
    _page.timer?.cancel();
    if (_page.fx?.pending == null) return;
    {
      _page.saving = true;
      _page.error = null;
      _page.update();
    }
    try {
      if (retry) {
        await _page.fx!.retry();
      } else if (_page.fx!.pending!.operation == null) {
        await _page.fx!.send(_page.fx!.pending!);
      } else {
        await _page.fx!.refresh();
      }
      await handle();
    } catch (failure) {
      if (mounted) {
        fail(failure);
        _page.update();
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
  ) => GetBuilder<_InvoiceChangeScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(
          context,
          text: 'اصلاح فاکتور ${widget.invoice.number}',
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
                'عملیات در حال پیگیری است؛ تا تعیین نتیجه، درخواست دیگری ثبت نمی‌شود.',
              ),
              Text(
                'وضعیت پردازش: ${const {'PENDING': 'در صف', 'PROCESSING': 'در حال پردازش', 'RETRY': 'در انتظار تلاش مجدد', 'ACTION_REQUIRED': 'نیازمند پیگیری', 'SUCCEEDED': 'تکمیل‌شده', 'FAILED': 'ناموفق'}[_page.fx!.pending!.operation?['status']] ?? 'پاسخ دریافت نشده'}',
              ),
              BTN(
                name: 'پیگیری عملیات فاکتور',
                disabled: _page.saving,
                onTap: track,
              ),
              if ([
                    'RETRY',
                    'ACTION_REQUIRED',
                  ].contains(_page.fx!.pending!.operation?['status']) &&
                  _page.fx!.access.has('accounting.invoice.amend'))
                BTN(
                  name: 'بازیابی پردازش فاکتور',
                  disabled: _page.saving,
                  onTap: () => track(retry: true),
                ),
            ],
            if (_page.current != null) ...[
              IgnorePointer(
                ignoring: locked,
                child: LayoutBuilder(
                  builder: (context, constraints) => MyTab(
                    width: false,
                    widthSize: ((constraints.maxWidth - 30) / actions.length)
                        .clamp(0, 250)
                        .toDouble(),
                    tab: actions.keys.toList(),
                    enabledValues: actions.keys
                        .where((v) => allowed(actions[v]!))
                        .toSet(),
                    value: _page.action,
                    callback: (String v) {
                      _page.action.value = v;
                      _page.conversionConfirmed.value = 'خیر';
                      {
                        _page.update();
                      }
                    },
                  ),
                ),
              ),
              if (!allowed(mode))
                const Text(
                  'مجوز یا وضعیت فاکتور برای این عملیات مناسب نیست. فروش ارسال‌شده باید از بخش مرجوعی پیگیری شود.',
                ),
              if (mode == 'amend')
                const Text(
                  'کالای جدید اضافه کنید یا تعداد، قیمت و تخفیف اقلام را اصلاح کنید. تعداد صفر، ردیف را حذف می‌کند. مبالغ نهایی توسط سرور محاسبه می‌شوند.',
                ),
              if (mode == 'status') ...[
                Text(
                  'وضعیت فعلی: ${deliveries[_page.current!.detail.summary.deliveryStatus]}',
                ),
                const Text(
                  'آماده‌سازی، کالا را از انبار خارج نمی‌کند. اولین ثبت ارسال یا تحویل، خروج واقعی کالا را ثبت می‌کند. تحویل پس از ارسال، خروج دوباره ایجاد نمی‌کند. برگشت کالای ارسال‌شده از بخش مرجوعی انجام می‌شود.',
                ),
                LayoutBuilder(
                  // Use the actual panel width so every delivery state stays tappable.
                  builder: (context, constraints) => MyTab(
                    width: false,
                    widthSize:
                        ((constraints.maxWidth - 30) /
                                (deliveryOptions.length + 1))
                            .clamp(0, 250)
                            .toDouble(),
                    tab: [
                      'انتخاب نشده',
                      ...deliveryOptions.map((s) => deliveries[s]!),
                    ],
                    value: _page.deliveryStatus,
                    enabledValues: locked ? <String>{} : null,
                    callback: (String v) {
                      _page.deliveryStatus.value = v;
                    },
                  ),
                ),
              ],
              if (mode == 'return')
                const Text(
                  'تعداد واقعی کالای برگشتی را وارد کنید؛ ردیف خالی مرجوع نمی‌شود.',
                ),
              if (mode == 'cancel')
                Text(
                  widget.invoice.type == 'PROFORMA'
                      ? 'پیش‌فاکتور لغو می‌شود؛ وجه و موجودی جابه‌جا نمی‌شود.'
                      : 'لغو خرید شامل خروج واقعی تمام کالای باقی‌مانده است. فروش ارسال‌شده لغو ساده نمی‌شود؛ مرجوعی را انتخاب کنید.',
                ),
              if (mode == 'convert') ...[
                const Text(
                  'پیش‌فاکتور با همین اقلام و مبالغ به فروش «در انتظار تحویل» تبدیل و موجودی رزرو می‌شود. خروج واقعی کالا انجام نمی‌شود. موجودی، قیمت‌ها و قواعد فروش اعتباری توسط سرور بررسی می‌شوند.',
                ),
                Text(
                  'مبلغ فروش: ${Price.showWithCurrency(_page.current!.detail.summary.total)}',
                ),
                MyTab(
                  tab: const ['بدون دریافت وجه', 'دریافت کامل'],
                  value: _page.conversionPayment,
                  enabledValues: locked || _page.targetsLoading
                      ? <String>{}
                      : null,
                  callback: (String v) {
                    _page.conversionPayment.value = v;
                    _page.conversionConfirmed.value = 'خیر';
                    if (v == 'دریافت کامل') loadConversionTargets();
                    {
                      _page.update();
                    }
                  },
                ),
                if (_page.conversionPayment.value == 'دریافت کامل') ...[
                  Dropdown(
                    name: 'روش دریافت',
                    search: false,
                    itemValue: true,
                    disable: locked || _page.targetsLoading,
                    items_Value: const [
                      ItemValue(text: 'نقدی', data: 'CASH'),
                      ItemValue(text: 'واریز بانکی', data: 'BANK_TRANSFER'),
                      ItemValue(text: 'کارت', data: 'CARD'),
                    ],
                    onChange: (v) {
                      _page.conversionMethod = (v as ItemValue).data as String;
                      _page.conversionConfirmed.value = 'خیر';
                      loadConversionTargets();
                    },
                  ),
                  if (_page.targetsLoading) const LinearProgressIndicator(),
                  for (final target in _page.conversionTargets)
                    MiniBTN(
                      name:
                          '${_page.conversionTarget?.id == target.id ? '✓ ' : ''}${target.name}',
                      noFlex: true,
                      icon: IconsaxPlusLinear.wallet,
                      onTap: locked || _page.targetsLoading
                          ? null
                          : () {
                              _page.conversionTarget = target;
                              _page.conversionConfirmed.value = 'خیر';
                              _page.update();
                            },
                    ),
                  MiniBTN(
                    name: 'دریافت مجدد مقصدهای پرداخت',
                    noFlex: true,
                    icon: IconsaxPlusLinear.refresh,
                    onTap: locked || _page.targetsLoading
                        ? null
                        : loadConversionTargets,
                  ),
                  const Text(
                    'تأیید زیر شامل دریافت واقعی کل مبلغ در مقصد انتخاب‌شده است؛ این دکمه پرداخت بانکی یا کارتخوان انجام نمی‌دهد.',
                  ),
                ],
                const Text('تبدیل به فروش و رزرو موجودی را تأیید می‌کنید؟'),
                MyTab(
                  tab: const ['خیر', 'بله'],
                  value: _page.conversionConfirmed,
                  enabledValues: locked || !allowed(mode) ? <String>{} : null,
                  callback: (String v) => _page.conversionConfirmed.value = v,
                ),
              ],
              if (mode != 'convert' && mode != 'status')
                const Text(
                  'این فرم وجهی جابه‌جا نمی‌کند؛ اعتبار و مانده‌ها توسط سرور اصلاح می‌شوند. برگشت واقعی وجه از بخش دریافت‌وپرداخت پیگیری می‌شود.',
                ),
              if (mode == 'amend')
                MiniBTN(
                  name: 'افزودن کالای جدید',
                  icon: IconsaxPlusLinear.add,
                  noFlex: true,
                  onTap: locked || !allowed(mode) ? null : addProduct,
                ),
              for (final line
                  in mode == 'amend'
                      ? editableLines
                      : _page.current!.lines) ...[
                MyDivider(text: RemoteJson(line).text('name')),
                Text(
                  _page.added.any((r) => r['lineId'] == line['lineId'])
                      ? 'کالای جدید؛ قبل از ثبت قابل حذف است.'
                      : 'تعداد فعلی: ${line['quantity']}',
                ),
                if (mode == 'amend') ...[
                  Input(
                    key: ValueKey('change-quantity-${line['lineId']}'),
                    controller: _page.quantities[line['lineId']]!,
                    name: 'تعداد جدید',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    readOnly: locked || !allowed(mode),
                  ),
                  Input(
                    controller: _page.prices[line['lineId']]!,
                    name: 'قیمت واحد (تومان)',
                    keyboardType: TextInputType.number,
                    readOnly:
                        locked ||
                        !allowed(mode) ||
                        widget.invoice.type != 'PURCHASE' &&
                            !_page.fx!.access.has(
                              'accounting.sale.price.override',
                            ),
                  ),
                  Input(
                    controller: _page.discounts[line['lineId']]!,
                    name: 'تخفیف ردیف (تومان)',
                    keyboardType: TextInputType.number,
                    readOnly: locked || !allowed(mode),
                  ),
                ],
                if (mode == 'return')
                  Input(
                    key: ValueKey('return-quantity-${line['lineId']}'),
                    controller: _page.returns[line['lineId']]!,
                    name: 'تعداد برگشتی',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    readOnly: locked || !allowed(mode),
                  ),
                if (mode != 'status' &&
                    _page.current!.posted &&
                    !_page.added.any((r) => r['lineId'] == line['lineId'])) ...[
                  const Text('وضعیت کالایی که برگشت داده می‌شود'),
                  IgnorePointer(
                    ignoring: locked || !allowed(mode),
                    child: MyTab(
                      tab: const ['انتخاب نشده', 'سالم', 'آسیب‌دیده'],
                      value: _page.conditions[line['lineId']]!,
                      callback: (String v) =>
                          _page.conditions[line['lineId']]!.value = v,
                    ),
                  ),
                ],
              ],
              if (mode == 'amend')
                for (final key in _page.totals.keys)
                  Input(
                    controller: _page.totals[key]!,
                    name: totalNames[key]!,
                    keyboardType: TextInputType.number,
                    readOnly: locked || !allowed(mode),
                  ),
              if (mode != 'convert')
                Input(
                  key: const ValueKey('invoice-change-reason'),
                  controller: _page.reason,
                  name: 'دلیل عملیات',
                  require: true,
                  maxLength: 500,
                  readOnly: locked || !allowed(mode),
                ),
              BTN(
                name: 'ثبت ${_page.action.value} فاکتور',
                disabled: locked || !allowed(mode),
                onTap: submit,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget buildInvoiceChangeRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return InvoiceChangeScreen(
    appId: args.required<String>('appId'),
    invoice: args.required<RemoteInvoiceSummary>('invoice'),
    delivery: args.optional<bool>('delivery') ?? false,
  );
}
