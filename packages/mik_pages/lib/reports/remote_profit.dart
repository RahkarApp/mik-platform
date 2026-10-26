import 'package:mik_data/utils/fx/realtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/base/main/mobile.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/dashboard.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/dashboard_read.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_data/utils/fx/profit_report.dart';
import 'package:mik_utils/public/date.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'financial_screen.dart' show financialMoney;

class RemoteProfitReport extends StatefulWidget {
  final String appId;
  const RemoteProfitReport({required this.appId, super.key});
  @override
  State<RemoteProfitReport> createState() => _RemoteProfitReportState();
}

class _RemoteProfitReportController extends GetxController {
  final period = 'هفته'.obs;
  ProfitReportFX? fx;
  ProfitReportData? data;
  bool full = false, column = false, loading = true;
  String? error;
  int generation = 0;
  RealtimeWatch? _realtime;
}

class _RemoteProfitReportState extends State<RemoteProfitReport> {
  late final _page = _RemoteProfitReportController();

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
        () => load(background: true),
        busy: () => _page.loading,
        invalidate: () {
          if (mounted) {
            {
              _page.generation++;
              _page.loading = false;
              _page.data = null;
              _page.update();
            }
          }
        },
      );
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    _page._realtime?.dispose();
    _page.generation++;
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> load({bool background = false}) async {
    final request = ++_page.generation;
    {
      if (!background) _page.loading = true;
      if (!background) _page.data = null;
      _page.error = null;
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= ProfitReportFX(DashboardReadFX(active));
      final result = await _page.fx!.load(
        _page.period.value,
        isActive: () => mounted && _page.generation == request,
      );
      if (mounted && _page.generation == request) {
        _page.data = result;
        _page.update();
      }
    } catch (failure) {
      if (mounted && _page.generation == request) {
        _page.error = FinancialReportsFX.message(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted && _page.generation == request) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  Future<void> details() async {
    final result = _page.data;
    if (result == null || _page.loading) return;
    try {
      _page.fx!.dashboard.check();
    } catch (failure) {
      Alert.error(FinancialReportsFX.message(failure), context: context);
      return;
    }
    await MyBottomSheet.view(
      context,
      title: 'جزئیات سود و زیان',
      child: (controller) => SingleChildScrollView(
        controller: controller,
        child: Column(
          children: [
            pair('شعبه', _page.fx!.dashboard.context.selectedBranch!.name),
            pair(
              'از تاریخ',
              DateConvertor.grigoriToJalali(result.summary.startAt),
            ),
            pair(
              'تا زمان دریافت گزارش',
              DateConvertor.grigoriToJalali(result.summary.endAt),
            ),
            MyDivider(text: 'درآمد و هزینه (تومان)'),
            pair('فروش خالص', financialMoney(result.money('netSales'))),
            pair(
              'بهای تمام‌شده کالای فروش‌رفته',
              financialMoney(result.money('costOfGoodsSold')),
            ),
            pair('سایر درآمدها', financialMoney(result.money('otherIncome'))),
            pair('هزینه‌ها', financialMoney(result.money('expenses'))),
            pair(
              'سود ناخالص',
              result.grossProfit == null
                  ? 'نامشخص'
                  : financialMoney(result.grossProfit),
            ),
            pair(
              'سود خالص قبل از مالیات',
              result.summary.profit == null
                  ? 'نامشخص'
                  : financialMoney(result.summary.profit),
            ),
            const Text(
              'درآمد بر مبنای تحویل واقعی کالا و برگشت آن است؛ تاریخ ایجاد فاکتور یا دریافت وجه، مبنای شناسایی سود نیست.',
              textAlign: TextAlign.center,
            ),
            if (!result.summary.complete)
              const Text(
                'بهای تمام‌شده یا ثبت‌های انبار کامل نیست؛ سود قطعی این بازه هنوز مشخص نیست.',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget pair(String name, Object value) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        Expanded(child: Text(name)),
        const SizedBox(width: 12),
        Expanded(child: Text('$value', textAlign: TextAlign.end)),
      ],
    ),
  );
  String get title => switch (_page.period.value) {
    'هفته' => 'نمودار سود هفتگی ',
    'ماه' => 'نمودار سود ماهانه ',
    'فصل' => 'نمودار سود فصلی ',
    _ => 'نمودار سود سالانه ',
  };
  String get currentName => _page.period.value == 'سال'
      ? 'سود امسال'
      : 'سود این ${_page.period.value}';
  String get previousName => _page.period.value == 'سال'
      ? 'سود سال گذشته'
      : 'سود ${_page.period.value} گذشته';
  @override
  Widget build(BuildContext context) {
    return GetBuilder<_RemoteProfitReportController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final header = Header.page(
          context,
          text: title,
          child: SizedBox(
            // Keep room for the native header's back button, title and help icon.
            width: (MediaQuery.sizeOf(context).width - 230).clamp(160.0, 340.0),
            height: 30,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MyTab(
                    tab: const ['هفته', 'ماه', 'فصل', 'سال'],
                    value: _page.period,
                    width: false,
                    widthSize: 55,
                    height: 50,
                    callback: (value) {
                      if (_page.period.value != value) {
                        _page.period.value = value as String;
                        load();
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  BTN(
                    margin: EdgeInsets.zero,
                    borderOnly: true,
                    color: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    name: _page.column ? 'نمودار خطی' : 'نمودار میله‌ای',
                    onTap: () {
                      _page.column = !_page.column;
                      _page.update();
                    },
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        );
        final fab = MyFAB(
          icon: _page.full
              ? IconsaxPlusLinear.back_square
              : IconsaxPlusLinear.maximize,
          text: _page.full ? 'بازگشت' : 'تمام صفحه',
          onTap: () {
            _page.full = !_page.full;
            _page.update();
          },
        );
        if (_page.full) {
          return MainMobile(
            header: header,
            floatingActionButton: fab,
            initState: () async => '',
            child: (_) => content(),
          );
        }
        return Main(
          header: header,
          floatingActionButton: fab,
          initState: () async => '',
          child: (_) => content(),
        );
      },
    );
  }

  Widget content() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        if (_page.loading) const LinearProgressIndicator(),
        if (_page.error != null)
          Text(_page.error!, textAlign: TextAlign.center),
        if (_page.data?.incomplete == true)
          const Text(
            'سود بازه‌های دارای بهای تمام‌شده ناقص، نامشخص است؛ نقاط خالی صفر نیستند.',
            textAlign: TextAlign.center,
          ),
        Expanded(
          child: _page.data == null
              ? const SizedBox.shrink()
              : SfCartesianChart(
                  primaryXAxis: CategoryAxis(
                    labelStyle: TextStyle(
                      fontFamily:
                          widget.appId == 'mikyar' &&
                              _page.period.value == 'هفته'
                          ? 'raviLight'
                          : 'ravi',
                    ),
                    labelPlacement: _page.period.value == 'ماه'
                        ? LabelPlacement.onTicks
                        : LabelPlacement.betweenTicks,
                  ),
                  primaryYAxis: NumericAxis(
                    maximumLabels: 10,
                    labelStyle: const TextStyle(fontFamily: 'ravi'),
                    numberFormat: NumberFormat.compact(),
                  ),
                  enableAxisAnimation: true,
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    shared: true,
                    format: 'point.x : point.y تومان',
                  ),
                  series: _page.column
                      ? [
                          ColumnSeries<DashboardProfitPoint, String>(
                            dataSource: _page.data!.points,
                            name: currentName,
                            xValueMapper: (p, _) => p.label,
                            yValueMapper: (p, _) => p.current,
                            color: AppColors.primary,
                            emptyPointSettings: const EmptyPointSettings(
                              mode: EmptyPointMode.gap,
                            ),
                          ),
                          ColumnSeries<DashboardProfitPoint, String>(
                            dataSource: _page.data!.points,
                            name: previousName,
                            xValueMapper: (p, _) => p.label,
                            yValueMapper: (p, _) => p.previous,
                            color: AppColors.secondary,
                            emptyPointSettings: const EmptyPointSettings(
                              mode: EmptyPointMode.gap,
                            ),
                          ),
                        ]
                      : [
                          LineSeries<DashboardProfitPoint, String>(
                            dataSource: _page.data!.points,
                            name: currentName,
                            xValueMapper: (p, _) => p.label,
                            yValueMapper: (p, _) => p.current,
                            color: AppColors.primary,
                            emptyPointSettings: const EmptyPointSettings(
                              mode: EmptyPointMode.gap,
                            ),
                          ),
                          LineSeries<DashboardProfitPoint, String>(
                            dataSource: _page.data!.points,
                            name: previousName,
                            xValueMapper: (p, _) => p.label,
                            yValueMapper: (p, _) => p.previous,
                            color: AppColors.secondary,
                            emptyPointSettings: const EmptyPointSettings(
                              mode: EmptyPointMode.gap,
                            ),
                          ),
                        ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 20,
            runSpacing: 4,
            children: [
              legend(AppColors.primary, currentName),
              legend(AppColors.secondary, previousName),
              MiniBTN(
                name: _page.error == null ? 'جزئیات گزارش' : 'دریافت مجدد',
                noFlex: true,
                icon: IconsaxPlusLinear.chart,
                onTap: _page.loading
                    ? null
                    : _page.error == null
                    ? details
                    : load,
              ),
              if (_page.error == null)
                MiniBTN(
                  name: 'دریافت مجدد',
                  noFlex: true,
                  icon: IconsaxPlusLinear.refresh,
                  onTap: _page.loading ? null : load,
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget legend(Color color, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        margin: const EdgeInsets.only(left: 10),
        height: 1.7,
        width: 30,
        color: color,
      ),
      Text(text),
    ],
  );
}
