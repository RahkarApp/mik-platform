import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:mik_data/utils/fx/realtime.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_components/elements/myTextScroll.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/models/invoice_read.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/price.dart';

import 'read_controller.dart';

import 'package:mik_components/elements/productImage.dart';
import 'package:mik_variables/variable.dart';

import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/invoice_read.dart';

// Reports may reference a document outside the currently loaded invoice page.
Future<void> viewReportedInvoice(
  BuildContext context, {
  required String appId,
  required String invoiceId,
  required String type,
}) async {
  final controller = InvoiceReadController(
    appId: appId,
    onNotice: (message, success) {
      if (context.mounted && !success) Alert.error(message, context: context);
    },
  );
  try {
    final active = BusinessContext.forApp(appId);
    if (active == null) throw const AuthError(401, 'SESSION_INVALID');
    final fx = InvoiceReadFX(active);
    controller.fx = fx;
    final detail = await fx.detail(invoiceId, type);
    if (!context.mounted) return;
    await Get.toNamed(
      nav_routes.RoutesName.REMOTE_INVOICE_DETAIL,
      arguments: {'c': controller, 'row': detail.summary},
      preventDuplicates: false,
    );
  } catch (failure) {
    if (context.mounted) {
      Alert.error(InvoiceReadFX.message(failure), context: context);
    }
  } finally {
    controller.onClose();
  }
}

const _types = {'SALE': 'فروش', 'PURCHASE': 'خرید', 'PROFORMA': 'پیش‌فاکتور'};
const _statuses = {
  'DRAFT': 'پیش‌نویس',
  'ISSUED': 'ثبت‌شده',
  'CANCELLED': 'لغوشده',
  'EXPIRED': 'منقضی‌شده',
  'CONVERTED': 'تبدیل‌شده',
};
const _deliveries = {
  'PENDING': 'در انتظار',
  'READY': 'آماده',
  'SHIPPED': 'ارسال‌شده',
  'DELIVERED': 'تحویل‌شده',
};
const _payments = {
  'UNPAID': 'پرداخت‌نشده',
  'PARTIALLY_PAID': 'پرداخت جزئی',
  'PAID': 'تسویه‌شده',
};

class RemoteInvoicesScreen extends StatefulWidget {
  final String appId;
  final bool includeProforma;
  const RemoteInvoicesScreen({
    required this.appId,
    this.includeProforma = false,
    super.key,
  });
  @override
  State<RemoteInvoicesScreen> createState() => _RemoteInvoicesScreenState();
}

class _RemoteInvoicesScreenState extends State<RemoteInvoicesScreen> {
  late final c = InvoiceReadController(
    appId: widget.appId,
    onNotice: (message, success) {
      if (!mounted) return;
      if (success) {
        Alert.success(message);
      } else {
        Alert.error(message, context: context);
      }
    },
  );
  List<String> get types => [
    if (widget.includeProforma) 'PROFORMA',
    'SALE',
    'PURCHASE',
  ];
  @override
  void dispose() {
    c.onClose();
    super.dispose();
  }

  Future<Object> load() async {
    await c.load();
    return '';
  }

  Future<void> filter() async {
    final chosen = await MyBottomSheet.view(
      context,
      title: 'فیلتر فاکتورها',
      child: (_) => Column(
        children: [
          for (final entry in {'': 'همه وضعیت‌ها', ..._statuses}.entries)
            MiniBTN(
              name: entry.value,
              noFlex: true,
              icon: IconsaxPlusLinear.filter,
              onTap: () => Get.back(result: entry.key),
            ),
          BTN(
            name: 'فیلتر تاریخ و تسویه',
            onTap: () => Alert.info(
              'فیلتر تاریخ و وضعیت تسویه در API فعلی فهرست پشتیبانی نمی‌شود.',
            ),
          ),
        ],
      ),
    );
    if (!mounted || chosen == null) return;
    c.status.value = chosen == '' ? null : chosen as String;
    await c.load();
  }

  @override
  Widget build(BuildContext context) => Main(
    initState: load,
    header: Header.page(context, text: 'فاکتورها', isBack: false),
    child: (_) => Column(
      children: [
        const SizedBox(height: 10),
        Obx(
          () => MyTabBar(
            tabs: types.map((t) => _types[t]!).toList(),
            divider: false,
            currentIndex: types.indexOf(c.type.value),
            index: (i) => c.selectType(types[i as int]),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Obx(
                () => Text(
                  c.type.value == 'PROFORMA'
                      ? 'لیست پیش‌فاکتورها'
                      : 'لیست فاکتور‌های ${_types[c.type.value]}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: filter,
              icon: const RotatedBox(
                quarterTurns: 1,
                child: Icon(IconsaxPlusLinear.setting_5),
              ),
            ),
          ],
        ),
        Obx(
          () => c.status.value == null
              ? const SizedBox.shrink()
              : Text('وضعیت: ${_statuses[c.status.value]}'),
        ),
        Expanded(
          child: Obx(
            () => Column(
              children: [
                if (c.loading.value) const LinearProgressIndicator(),
                if (c.error.value != null) ...[
                  Text(c.error.value!, textAlign: TextAlign.center),
                  MiniBTN(
                    name: 'تلاش مجدد',
                    icon: IconsaxPlusLinear.refresh,
                    noFlex: true,
                    onTap: c.loading.value
                        ? null
                        : () => c.load(more: c.rows.isNotEmpty),
                  ),
                ],
                Expanded(
                  child: c.rows.isEmpty
                      ? c.loading.value || c.error.value != null
                            ? const SizedBox.shrink()
                            : EmptyList(
                                text: 'فاکتوری یافت نشد!',
                                icon: IconsaxPlusLinear.receipt,
                                child: MiniBTN(
                                  name: 'به‌روزرسانی',
                                  noFlex: true,
                                  icon: IconsaxPlusLinear.refresh,
                                  onTap: c.load,
                                ),
                              )
                      : RefreshIndicator(
                          onRefresh: c.load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              for (final row in c.rows)
                                RemoteInvoiceRow(
                                  row: row,
                                  onTap: () async {
                                    await Get.toNamed(
                                      nav_routes
                                          .RoutesName
                                          .REMOTE_INVOICE_DETAIL,
                                      arguments: {'c': c, 'row': row},
                                      preventDuplicates: false,
                                    );
                                    if (mounted) await c.load();
                                  },
                                ),
                              if (c.next.value != null)
                                BTN(
                                  name: 'نمایش بیشتر',
                                  disabled: c.loading.value,
                                  onTap: () => c.load(more: true),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class RemoteInvoiceRow extends StatelessWidget {
  final RemoteInvoiceSummary row;
  final VoidCallback onTap;
  final String? amountLabel;
  const RemoteInvoiceRow({
    required this.row,
    required this.onTap,
    this.amountLabel,
    super.key,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      InkWell(
        key: ValueKey('invoice-${row.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                maxRadius: 27,
                backgroundColor: AppColors.boxBackground,
                child: Icon(
                  row.type == 'PURCHASE'
                      ? IconsaxPlusLinear.import
                      : IconsaxPlusLinear.receipt,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${row.number} - ${row.partyName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(DateConvertor.grigoriToJalali(row.createdAt)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            amountLabel ?? Price.showWithCurrency(row.total),
                          ),
                        ),
                        Text(
                          row.paymentApplicable
                              ? _payments[row.paymentStatus]!
                              : 'تسویه قابل اعمال نیست',
                          style: TextStyle(
                            color: row.paymentStatus == 'PAID'
                                ? AppColors.success
                                : AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_statuses[row.status]} — ${_deliveries[row.deliveryStatus]}',
                    ),
                    if (row.operationId != null)
                      const Text('عملیات مرتبط در جریان است.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      EndLine(),
    ],
  );
}

class _RemoteInvoiceDetail extends StatefulWidget {
  final InvoiceReadController c;
  final RemoteInvoiceSummary row;
  const _RemoteInvoiceDetail({required this.c, required this.row});
  @override
  State<_RemoteInvoiceDetail> createState() => _RemoteInvoiceDetailState();
}

class _RemoteInvoiceDetailController extends GetxController {
  RemoteInvoiceDetail? detail;
  bool loading = false;
  bool itemsExpanded = true;
  String? openingDocument;
  RealtimeWatch? _realtime;
  int _readGeneration = 0;
}

class _RemoteInvoiceDetailState extends State<_RemoteInvoiceDetail> {
  // Each open invoice owns its state; another route must not replace its controller.
  late final _page = _RemoteInvoiceDetailController();

  @override
  void initState() {
    super.initState();
    final active = BusinessContext.forApp(widget.c.appId);
    if (active != null) {
      _page._realtime = RealtimeWatch(
        RealtimeFX.forContext(active),
        {
          'accounting.sale',
          'accounting.purchase',
          'accounting.proforma',
          'accounting.payment',
          'accounting.cheque',
          'accounting.event',
          'accounting.operation',
        },
        () async {
          while (mounted && _page.loading) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          if (mounted) await load(background: true);
        },
        invalidate: () {
          if (mounted) {
            {
              _page._readGeneration++;
              _page.loading = false;
              _page.detail = null;
              _page.update();
            }
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _page._realtime?.dispose();
    super.dispose();
  }

  Future<Object> load({bool initial = false, bool background = false}) async {
    if (_page.loading) return '';
    final generation = ++_page._readGeneration;
    void begin() {
      if (!background) {
        _page.loading = true;
        _page.detail = null;
      }
    }

    if (initial) {
      begin();
    } else {
      {
        begin();
        _page.update();
      }
    }
    final result = await widget.c.detail(widget.row.id, widget.row.type);
    if (mounted && generation == _page._readGeneration) {
      {
        _page.loading = false;
        _page.detail = result;
        _page.update();
      }
    }
    return '';
  }

  Future<void> viewRelated(RemoteInvoiceRelatedDocument document) async {
    if (_page.openingDocument != null) return;
    {
      _page.openingDocument = document.id;
      _page.update();
    }
    try {
      final result = await widget.c.fx!.detail(document.id, document.type);
      if (!mounted) return;
      await MyBottomSheet.view(
        context,
        title: 'سند ${document.number}',
        initialChildSize: 0.7,
        child: (controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            pair('وضعیت سند', _statuses[result.summary.status]!),
            pair('مبلغ سند', Price.showWithCurrency(result.summary.total)),
            MyDivider(text: 'اقلام این سند'),
            for (final line in result.lines) ...[
              pair(line.name, '× ${line.quantity}'),
              if (line.sku != null) pair('کد کالا', line.sku!),
              pair('مبلغ', Price.showWithCurrency(line.amount)),
              EndLine(),
            ],
            if (result.note != null) Text(result.note!),
          ],
        ),
      );
    } catch (failure) {
      if (mounted) {
        Alert.error(InvoiceReadFX.message(failure), context: context);
      }
    } finally {
      if (mounted) {
        _page.openingDocument = null;
        _page.update();
      }
    }
  }

  Widget pair(String name, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(name, style: const TextStyle(fontSize: 16))),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_RemoteInvoiceDetailController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () => load(initial: true),
      header: Header.page(
        context,
        text: 'جزئیات فاکتور ${_types[widget.row.type]} ${widget.row.number}',
      ),
      child: (_) => _page.detail == null
          ? Column(
              children: [
                if (_page.loading) const LinearProgressIndicator(),
                if (!_page.loading) ...[
                  Text(
                    widget.c.error.value ?? 'دریافت جزئیات فاکتور انجام نشد.',
                  ),
                  BTN(name: 'تلاش مجدد', onTap: load),
                ],
              ],
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        maxRadius: 20,
                        backgroundColor:
                            _page.detail!.summary.type == 'PURCHASE'
                            ? AppColors.blue
                            : AppColors.primary,
                        child: const Icon(
                          IconsaxPlusLinear.user,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MyTextScroll(
                          _page.detail!.summary.partyName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            DateConvertor.grigoriToJalali(
                              _page.detail!.summary.createdAt,
                            ),
                          ),
                          Text(
                            DateConvertor.showTime(
                              _page.detail!.summary.createdAt,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_page.detail!.summary.phone != null)
                    pair('شماره موبایل', _page.detail!.summary.phone!),
                  MyDivider(),
                  if (_page.detail!.returnStatus != null &&
                      _page.detail!.returnStatus != 'NONE') ...[
                    pair(
                      'وضعیت مرجوعی',
                      _page.detail!.returnStatus == 'FULL'
                          ? 'تمام کالاها مرجوع شده‌اند'
                          : 'بخشی از کالاها مرجوع شده‌اند',
                    ),
                    const Text(
                      'اقلام و مبلغ زیر، وضعیت فعلی فاکتور پس از تغییرات ثبت‌شده هستند.',
                    ),
                    MyDivider(),
                  ],
                  if (_page.detail!.summary.operationId != null) ...[
                    const Text(
                      'عملیات این فاکتور هنوز نهایی نشده است؛ نتیجه را از بخش ویرایش، لغو و مرجوعی پیگیری کنید.',
                    ),
                    MyDivider(),
                  ],
                  InkWell(
                    key: const ValueKey('invoice-detail-items'),
                    onTap: () {
                      _page.itemsExpanded = !_page.itemsExpanded;
                      _page.update();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _page.detail!.returnStatus == 'PARTIAL' ||
                                    _page.detail!.returnStatus == 'FULL'
                                ? 'اقلام باقی‌مانده: (${_page.detail!.lines.length})'
                                : 'اقلام سفارش: (${_page.detail!.lines.length})',
                            style: const TextStyle(fontSize: 18),
                          ),
                          AnimatedRotation(
                            turns: _page.itemsExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(IconsaxPlusLinear.arrow_down_1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: !_page.itemsExpanded
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            children: [
                              if (_page.detail!.lines.isEmpty)
                                Text(
                                  _page.detail!.returnStatus == 'FULL'
                                      ? 'همهٔ کالاها مرجوع شده‌اند؛ کالایی باقی نمانده است.'
                                      : 'فاکتور در نمای فعلی قلمی ندارد.',
                                ),
                              for (final line in _page.detail!.lines) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 10,
                                    bottom: 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ProductImage.noimg(
                                        'product',
                                        (MediaQuery.sizeOf(context).width / 6)
                                            .clamp(45, 90)
                                            .toDouble(),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: MyTextScroll(
                                                    line.name,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: darkMode.value
                                                          ? Colors.grey.shade400
                                                          : Colors
                                                                .grey
                                                                .shade700,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                Text('× ${line.quantity}'),
                                              ],
                                            ),
                                            if (line.sku != null)
                                              Text('کد کالا: ${line.sku}'),
                                            const SizedBox(height: 5),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    'فی: ${Price.show(line.unitPrice)}',
                                                  ),
                                                ),
                                                Flexible(
                                                  child: Text(
                                                    Price.showWithCurrency(
                                                      line.amount,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                EndLine(rightPadding: 60),
                              ],
                            ],
                          ),
                  ),
                  if (_page.detail!.relatedDocuments?.isNotEmpty == true) ...[
                    MyDivider(text: 'تاریخچه اسناد و مرجوعی‌ها'),
                    for (final document
                        in ([..._page.detail!.relatedDocuments!]..sort((a, b) {
                          final time = b.createdAt.compareTo(a.createdAt);
                          return time != 0
                              ? time
                              : b.number.compareTo(a.number);
                        }))) ...[
                      pair(
                        document.financialOnly
                            ? 'اصلاح مالی'
                            : switch (document.type) {
                                'SALE_RETURN' => 'مرجوعی فروش',
                                'PURCHASE_RETURN' => 'مرجوعی خرید',
                                'SALE' => 'فروش',
                                'PURCHASE' => 'خرید',
                                'PROFORMA' => 'پیش‌فاکتور',
                                _ => 'پیش‌فروش',
                              },
                        'شماره ${document.number}',
                      ),
                      pair(
                        'تاریخ',
                        '${DateConvertor.grigoriToJalali(document.createdAt)} ${DateConvertor.showTime(document.createdAt)}',
                      ),
                      pair('وضعیت سند', _statuses[document.status]!),
                      pair('مبلغ سند', Price.showWithCurrency(document.amount)),
                      if (!document.financialOnly &&
                          [
                            'SALE_RETURN',
                            'PURCHASE_RETURN',
                          ].contains(document.type))
                        BTN(
                          name: _page.openingDocument == document.id
                              ? 'در حال دریافت اقلام…'
                              : 'مشاهده اقلام این مرجوعی',
                          onTap: () => viewRelated(document),
                        ),
                      EndLine(),
                    ],
                  ],
                  MyDivider(text: 'جزئیات فاکتور'),
                  pair('شماره فاکتور', _page.detail!.summary.number),
                  pair(
                    'تاریخ ثبت',
                    DateConvertor.grigoriToJalali(
                      _page.detail!.summary.createdAt,
                    ),
                  ),
                  pair('شعبه', widget.c.fx!.branchName),
                  pair('وضعیت', _statuses[_page.detail!.summary.status]!),
                  pair(
                    'تحویل',
                    _deliveries[_page.detail!.summary.deliveryStatus]!,
                  ),
                  for (final entry in {
                    'subtotal': 'جمع اقلام',
                    'lineDiscount': 'تخفیف اقلام',
                    'discountAmount': 'تخفیف فاکتور',
                    'shippingAmount': 'هزینه ارسال',
                    'surchargeAmount': 'سایر هزینه‌ها',
                    'taxAmount': 'مالیات',
                    'total':
                        _page.detail!.returnStatus == 'PARTIAL' ||
                            _page.detail!.returnStatus == 'FULL'
                        ? 'مبلغ فعلی پس از مرجوعی'
                        : 'مبلغ نهایی',
                  }.entries)
                    pair(
                      entry.value,
                      Price.showWithCurrency(_page.detail!.totals[entry.key]!),
                    ),
                  MyDivider(),
                  pair(
                    'وضعیت تسویه',
                    _page.detail!.summary.paymentApplicable
                        ? _payments[_page.detail!.summary.paymentStatus]!
                        : 'قابل اعمال نیست',
                  ),
                  if (_page.detail!.summary.paymentApplicable) ...[
                    pair(
                      'مبلغ تسویه‌شده',
                      Price.showWithCurrency(_page.detail!.settledAmount),
                    ),
                    pair(
                      'مانده حساب',
                      Price.showWithCurrency(_page.detail!.summary.openAmount),
                    ),
                  ],
                  if (_page.detail!.summary.paymentApplicable &&
                      _page.detail!.summary.paymentStatus == 'PAID')
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Transform.rotate(
                          angle: -0.15,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.5),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _page.detail!.returnStatus == 'FULL'
                                  ? 'مرجوعی کامل'
                                  : 'پرداخت شده',
                              style: TextStyle(
                                color: AppColors.error.withValues(alpha: 0.5),
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if ([
                        'SALE',
                        'PURCHASE',
                      ].contains(_page.detail!.summary.type) &&
                      [
                        'ISSUED',
                        'CANCELLED',
                      ].contains(_page.detail!.summary.status))
                    MiniBTN(
                      name: 'دریافت‌وپرداخت و تسویه',
                      noFlex: true,
                      icon: IconsaxPlusLinear.wallet,
                      onTap: () async {
                        await Get.toNamed(
                          nav_routes.RoutesName.INVOICE_PAYMENT,
                          arguments: {
                            'appId': widget.c.appId,
                            'invoice': _page.detail!.summary,
                          },
                          preventDuplicates: false,
                        );
                        if (mounted) {
                          await load();
                          await widget.c.load();
                        }
                      },
                    ),
                  if (_page.detail!.summary.type == 'SALE')
                    MiniBTN(
                      name: 'مدیریت تحویل کالا',
                      noFlex: true,
                      icon: IconsaxPlusLinear.box,
                      onTap: () async {
                        await Get.toNamed(
                          nav_routes.RoutesName.INVOICE_CHANGE,
                          arguments: {
                            'appId': widget.c.appId,
                            'invoice': _page.detail!.summary,
                            'delivery': true,
                          },
                          preventDuplicates: false,
                        );
                        if (mounted) {
                          await load();
                          await widget.c.load();
                        }
                      },
                    ),
                  if ([
                    'SALE',
                    'PURCHASE',
                    'PROFORMA',
                  ].contains(_page.detail!.summary.type))
                    MiniBTN(
                      name: _page.detail!.summary.type == 'PROFORMA'
                          ? 'ویرایش، تبدیل و لغو پیش‌فاکتور'
                          : 'ویرایش، لغو و مرجوعی',
                      noFlex: true,
                      icon: IconsaxPlusLinear.edit,
                      onTap: () async {
                        final row = _page.detail!.summary;
                        await Get.toNamed(
                          nav_routes.RoutesName.INVOICE_CHANGE,
                          arguments: {'appId': widget.c.appId, 'invoice': row},
                          preventDuplicates: false,
                        );
                        if (mounted) {
                          await load();
                          await widget.c.load();
                        }
                      },
                    ),
                  if (_page.detail!.validUntil != null)
                    pair(
                      'مهلت اعتبار',
                      DateConvertor.grigoriToJalali(_page.detail!.validUntil!),
                    ),
                  if (_page.detail!.convertedInvoiceId != null)
                    MiniBTN(
                      name: 'مشاهده فاکتور فروش تبدیل‌شده',
                      noFlex: true,
                      icon: IconsaxPlusLinear.receipt,
                      onTap: () async {
                        final sale = await widget.c.detail(
                          _page.detail!.convertedInvoiceId!,
                          'SALE',
                        );
                        if (!context.mounted || sale == null) return;
                        await Get.toNamed(
                          nav_routes.RoutesName.REMOTE_INVOICE_DETAIL,
                          arguments: {'c': widget.c, 'row': sale.summary},
                          preventDuplicates: false,
                        );
                        if (mounted) await load();
                      },
                    ),
                  if (_page.detail!.summary.dueAt != null)
                    pair(
                      'مهلت پرداخت',
                      '${DateConvertor.grigoriToJalali(_page.detail!.summary.dueAt!.toLocal())} ${DateConvertor.showTime(_page.detail!.summary.dueAt!.toLocal())}',
                    ),
                  if (_page.detail!.note != null) ...[
                    MyDivider(text: 'توضیحات'),
                    Text(_page.detail!.note!),
                  ],
                  MiniBTN(
                    name: 'به‌روزرسانی',
                    noFlex: true,
                    icon: IconsaxPlusLinear.refresh,
                    onTap: load,
                  ),
                ],
              ),
            ),
    ),
  );
}

Widget buildRemoteInvoiceDetailRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _RemoteInvoiceDetail(
    c: args.required<InvoiceReadController>('c'),
    row: args.required<RemoteInvoiceSummary>('row'),
  );
}
