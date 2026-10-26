import 'package:mik_data/utils/fx/realtime.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/invoice_read.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/dashboard_read.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_utils/private/invoiceStatus.dart';
import 'package:mik_variables/variable.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import '../invoice/read_screen.dart';

class RemoteHomeInvoices extends StatefulWidget {
  final Future<void> Function() onMore;
  final int initialDays;
  final Future<void> Function(int)? onDaysChanged;
  const RemoteHomeInvoices({
    required this.onMore,
    this.initialDays = 7,
    this.onDaysChanged,
    super.key,
  });
  @override
  State<RemoteHomeInvoices> createState() => _RemoteHomeInvoicesState();
}

class _RemoteHomeInvoicesController extends GetxController {
  DashboardReadFX? fx;
  RealtimeWatch? _realtime;
  int _generation = 0;
  bool opening = false;
  List<RemoteInvoiceSummary> rows = [];
  bool loading = true;
  int days = 7;
  String? error;
}

class _RemoteHomeInvoicesState extends State<RemoteHomeInvoices> {
  late final _page = _RemoteHomeInvoicesController();

  @override
  void initState() {
    super.initState();
    final active = BusinessContext.forApp('mik');
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
        () => load(background: true),
        busy: () => _page.loading || _page.opening,
        invalidate: () {
          if (mounted) {
            {
              _page._generation++;
              _page.loading = false;
              _page.rows = [];
              _page.update();
            }
          }
        },
      );
    }
    _page.days = [7, 30, 90].contains(widget.initialDays)
        ? widget.initialDays
        : 7;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    _page._realtime?.dispose();
    _page._generation++;
    super.dispose();
  }

  Future<void> load({bool background = false}) async {
    if (!mounted) return;
    final request = ++_page._generation;
    {
      if (!background) _page.loading = true;
      _page.error = null;
      if (!background) _page.rows = [];
      _page.update();
    }
    try {
      final active = BusinessContext.forApp('mik');
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= DashboardReadFX(active);
      final result = await _page.fx!.invoices(
        isActive: () => mounted && request == _page._generation,
      );
      if (mounted && request == _page._generation) {
        _page.rows = result;
        _page.update();
      }
    } catch (failure) {
      if (mounted && request == _page._generation) {
        _page.error = FinancialReportsFX.message(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted && request == _page._generation) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  Future<void> select() async {
    if (_page.loading) return;
    final chosen = '${_page.days} روز'.obs;
    _page.opening = true;
    try {
      await MyBottomSheet.view(
        context,
        title: 'بازه زمانی گزارش',
        child: (_) => Column(
          children: [
            MyTab(
              tab: const ['7 روز', '30 روز', '90 روز'],
              value: chosen,
              callback: (value) {
                chosen.value = value as String;
                Get.back();
              },
            ),
            const Text(
              'آمار مربوط به فاکتورهای قابل مشاهده در شعبه است. فهرست سرور تعداد مرجوعی را مشخص نمی‌کند؛ لغو/مرجوع نامشخص نمایش داده می‌شود.',
              textAlign: TextAlign.center,
            ),
            MiniBTN(
              name: 'دریافت مجدد',
              icon: IconsaxPlusLinear.refresh,
              noFlex: true,
              onTap: () => Get.back(),
            ),
          ],
        ),
      );
    } finally {
      _page.opening = false;
    }
    if (!mounted) return;
    {
      _page.days = int.parse(chosen.value.split(' ').first);
      _page.update();
    }
    try {
      await widget.onDaysChanged?.call(_page.days);
    } catch (_) {
      if (mounted) Alert.error('ذخیره بازه گزارش انجام نشد.', context: context);
    }
    if (!mounted) return;
    await load();
  }

  Future<void> open(RemoteInvoiceSummary row) async {
    if (_page.loading) return;
    {
      _page.loading = true;
      _page.update();
    }
    try {
      _page.fx!.check();
      await viewReportedInvoice(
        context,
        appId: 'mik',
        invoiceId: row.id,
        type: row.type,
      );
    } catch (failure) {
      if (mounted) {
        Alert.error(FinancialReportsFX.message(failure), context: context);
      }
    }
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_RemoteHomeInvoicesController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final now = DateTime.now();
        final period = _page.rows
            .where(
              (r) =>
                  r.type != 'PURCHASE' &&
                  r.createdAt.isAfter(
                    now.subtract(Duration(days: _page.days)),
                  ) &&
                  !r.createdAt.isAfter(now),
            )
            .toList();
        final sales = period.where(
          (r) => r.type == 'SALE' && r.status == 'ISSUED',
        );
        final canSale =
            _page.fx?.reports.access.has('accounting.sale.read') == true;
        return Obx(
          () => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, right: 8, left: 8),
                height: 110,
                decoration: BoxDecoration(
                  color: darkMode.isFalse
                      ? Colors.white
                      : const Color.fromARGB(255, 36, 39, 42),
                  boxShadow: [
                    BoxShadow(
                      color: darkMode.isFalse
                          ? Colors.grey.shade300
                          : Colors.grey.shade900,
                      blurRadius: 5,
                      spreadRadius: 0,
                    ),
                  ],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    if (_page.loading)
                      const Center(child: CircularProgressIndicator()),
                    if (!_page.loading && _page.error == null)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.only(
                              top: 5,
                              right: 5,
                              bottom: 5,
                            ),
                            alignment: Alignment.topRight,
                            child: Text(
                              canSale ||
                                      _page.fx!.reports.access.has(
                                        'accounting.proforma.read',
                                      )
                                  ? '${_page.days} روز گذشته (مجموعا ${period.length} فاکتور)'
                                  : 'آمار فروش قابل مشاهده نیست',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                if (_page.fx!.reports.access.has(
                                  'accounting.proforma.read',
                                ))
                                  counter(
                                    900,
                                    period
                                        .where(
                                          (r) =>
                                              r.type == 'PROFORMA' &&
                                              r.status == 'ISSUED',
                                        )
                                        .length,
                                    'پیش‌فاکتور',
                                    period.length,
                                  ),
                                counter(
                                  1,
                                  canSale
                                      ? sales
                                            .where(
                                              (r) =>
                                                  r.deliveryStatus == 'PENDING',
                                            )
                                            .length
                                      : null,
                                  'ثبت شده',
                                  period.length,
                                ),
                                counter(
                                  2,
                                  canSale
                                      ? sales
                                            .where(
                                              (r) =>
                                                  r.deliveryStatus == 'READY',
                                            )
                                            .length
                                      : null,
                                  'آماده ارسال',
                                  period.length,
                                ),
                                counter(
                                  3,
                                  canSale
                                      ? sales
                                            .where(
                                              (r) => [
                                                'SHIPPED',
                                                'DELIVERED',
                                              ].contains(r.deliveryStatus),
                                            )
                                            .length
                                      : null,
                                  'ارسال شده',
                                  period.length,
                                ),
                                counter(9, null, 'لغو/مرجوع', period.length),
                              ],
                            ),
                          ),
                        ],
                      ),
                    if (_page.error != null)
                      Center(
                        child: Text(_page.error!, textAlign: TextAlign.center),
                      ),
                    Positioned(
                      top: 4,
                      left: 8,
                      child: InkWell(
                        onTap: _page.loading ? null : select,
                        child: const RotatedBox(
                          quarterTurns: 1,
                          child: Icon(IconsaxPlusLinear.setting_5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.only(top: 18, right: 10, left: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'آخرین فاکتورها',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    InkWell(
                      onTap: _page.loading
                          ? null
                          : () async {
                              await widget.onMore();
                              if (mounted) await load();
                            },
                      child: Row(
                        children: [
                          Text(
                            'بیشتر',
                            style: TextStyle(
                              color: darkMode.value
                                  ? AppColors.primaryLite
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            IconsaxPlusLinear.arrow_left_1,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              MyDivider(),
              Expanded(
                child: _page.loading
                    ? const SizedBox.shrink()
                    : _page.error != null
                    ? MiniBTN(
                        name: 'دریافت مجدد',
                        icon: IconsaxPlusLinear.refresh,
                        noFlex: true,
                        onTap: load,
                      )
                    : _page.rows.isEmpty
                    ? const Center(child: Text('فاکتوری ثبت نشده است.'))
                    : ListView(
                        children: [
                          for (final row in _page.rows.take(10))
                            RemoteInvoiceRow(
                              row: row,
                              amountLabel:
                                  '${row.total.toString().seRagham()} تومان',
                              onTap: () => open(row),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget counter(int status, int? count, String name, int total) => Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 5,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(count?.toString() ?? '—'),
              SizedBox(
                height: 50,
                width: 50,
                child: CircularProgressIndicator(
                  value: count == null ? 0 : count / (total == 0 ? 1 : total),
                  color: InvoiceStatus.color(status),
                  strokeWidth: 5,
                  backgroundColor: InvoiceStatus.color(status)
                      .withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(name, style: const TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}
