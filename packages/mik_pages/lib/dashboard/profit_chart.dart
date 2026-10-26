import 'package:mik_data/utils/fx/realtime.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/dashboard.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/dashboard_read.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_variables/variable.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class RemoteProfitHomeChart extends StatefulWidget {
  final String appId;
  final double height;
  final String initialPeriod;
  final Future<void> Function(String)? onPeriodChanged;
  const RemoteProfitHomeChart({
    required this.appId,
    required this.height,
    this.initialPeriod = 'سود هفته',
    this.onPeriodChanged,
    super.key,
  });
  @override
  State<RemoteProfitHomeChart> createState() => _RemoteProfitHomeChartState();
}

class _RemoteProfitHomeChartController extends GetxController {
  DashboardReadFX? fx;
  RealtimeWatch? _realtime;
  int _generation = 0;
  bool opening = false;
  final period = 'سود هفته'.obs;
  bool loading = true, incomplete = false;
  String? error;
  List<DashboardProfitPoint> points = [];
}

class _RemoteProfitHomeChartState extends State<RemoteProfitHomeChart> {
  late final _page = _RemoteProfitHomeChartController();

  @override
  void initState() {
    super.initState();
    final active = BusinessContext.forApp(widget.appId);
    if (active != null) {
      _page._realtime = RealtimeWatch(
        RealtimeFX.forContext(active),
        {
          'accounting.sale',
          'accounting.purchase',
          'accounting.sale-return',
          'accounting.purchase-return',
          'accounting.expense',
          'accounting.disbursement',
          'accounting.journal',
          'accounting.loan-entry',
          'accounting.asset-movement',
          'accounting.stock-cost',
          'inventory.valuation',
          'inventory.cost-entry',
        },
        () => load(background: true),
        busy: () => _page.loading || _page.opening,
        invalidate: () {
          if (mounted) {
            {
              _page._generation++;
              _page.loading = false;
              _page.points = [];
              _page.incomplete = false;
              _page.update();
            }
          }
        },
      );
    }
    _page.period.value = ['سود هفته', 'سود ماه'].contains(widget.initialPeriod)
        ? widget.initialPeriod
        : 'سود هفته';
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
      if (!background) _page.points = [];
      if (!background) _page.incomplete = false;
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= DashboardReadFX(active);
      final data = await _page.fx!.profitChart(
        month: _page.period.value == 'سود ماه',
        isActive: () => mounted && request == _page._generation,
      );
      if (mounted && request == _page._generation) {
        {
          _page.points = data.points;
          _page.incomplete = data.incomplete;
          _page.update();
        }
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
    final choice = _page.period.value.obs;
    _page.opening = true;
    try {
      await MyBottomSheet.view(
        context,
        title: 'نوع گزارش را انتخاب کنید',
        child: (_) => Column(
          children: [
            const SizedBox(height: 20),
            MyTab(
              tab: const ['سود هفته', 'سود ماه'],
              value: choice,
              callback: (value) {
                choice.value = value as String;
                Get.back();
              },
            ),
            const Text(
              'سود خالص قبل از مالیات، بر مبنای تحویل واقعی کالا و هزینه‌های ثبت‌شده، به تومان. سود ناقص و روزهای آینده ستون ندارند.',
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
    _page.period.value = choice.value;
    try {
      await widget.onPeriodChanged?.call(_page.period.value);
    } catch (_) {
      if (mounted) {
        Alert.error('ذخیره انتخاب گزارش انجام نشد.', context: context);
      }
    }
    if (!mounted) return;
    await load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_RemoteProfitHomeChartController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Obx(
      () => Container(
        margin: const EdgeInsets.only(top: 5, right: 8, left: 8),
        height: widget.height,
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
            if (_page.loading) const Center(child: CircularProgressIndicator()),
            if (_page.error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(_page.error!, textAlign: TextAlign.center),
                ),
              ),
            if (!_page.loading && _page.error == null) ...[
              Positioned(
                top: 3,
                right: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    legend(
                      AppColors.primary,
                      _page.period.value == 'سود هفته'
                          ? 'سود این هفته'
                          : 'سود این ماه',
                    ),
                    legend(
                      AppColors.secondary,
                      _page.period.value == 'سود هفته'
                          ? 'سود هفته گذشته'
                          : 'سود ماه گذشته',
                    ),
                  ],
                ),
              ),
              SfCartesianChart(
                margin: EdgeInsets.zero,
                primaryXAxis: CategoryAxis(
                  axisLine: AxisLine(color: AppColors.disable),
                  tickPosition: TickPosition.inside,
                  majorTickLines: const MajorTickLines(size: 0),
                  labelStyle: TextStyle(
                    fontFamily: widget.appId == 'mik' ? 'ravi' : 'raviLight',
                    fontSize: 8,
                    color: AppColors.grey,
                  ),
                ),
                primaryYAxis: NumericAxis(
                  maximumLabels: 3,
                  isVisible: false,
                  axisLine: AxisLine(color: AppColors.disable),
                  tickPosition: TickPosition.inside,
                  numberFormat: NumberFormat.compact(),
                ),
                enableAxisAnimation: true,
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  elevation: 1,
                  shared: true,
                  format: 'point.x : point.y تومان',
                  textStyle: TextStyle(
                    color: darkMode.isFalse
                        ? AppColors.backgroundDarkMode
                        : AppColors.background,
                  ),
                  color: darkMode.isTrue
                      ? AppColors.backgroundDarkMode
                      : AppColors.background,
                ),
                series: [
                  ColumnSeries<DashboardProfitPoint, String>(
                    dataSource: _page.points,
                    name: _page.period.value == 'سود هفته'
                        ? 'سود این هفته'
                        : 'سود این ماه',
                    spacing: 0.1,
                    borderRadius: BorderRadius.circular(10),
                    xValueMapper: (p, _) => p.label,
                    yValueMapper: (p, _) => p.current,
                    emptyPointSettings: const EmptyPointSettings(
                      mode: EmptyPointMode.gap,
                    ),
                    color: AppColors.primary,
                  ),
                  ColumnSeries<DashboardProfitPoint, String>(
                    dataSource: _page.points,
                    name: _page.period.value == 'سود هفته'
                        ? 'سود هفته گذشته'
                        : 'سود ماه گذشته',
                    spacing: 0.1,
                    borderRadius: BorderRadius.circular(10),
                    xValueMapper: (p, _) => p.label,
                    yValueMapper: (p, _) => p.previous,
                    emptyPointSettings: const EmptyPointSettings(
                      mode: EmptyPointMode.gap,
                    ),
                    color: AppColors.secondary,
                  ),
                ],
              ),
              if (_page.incomplete)
                const Positioned(
                  bottom: 24,
                  left: 8,
                  right: 8,
                  child: Text(
                    'بخشی از سود به‌علت تکمیل‌نشدن بهای تمام‌شده نامشخص است.',
                    style: TextStyle(fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
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
    ),
  );
  Widget legend(Color color, String text) => Row(
    spacing: 5,
    children: [
      CircleAvatar(backgroundColor: color, maxRadius: 5),
      Text(text, style: const TextStyle(fontSize: 10)),
    ],
  );
}
