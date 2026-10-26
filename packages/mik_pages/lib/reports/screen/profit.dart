// ignore_for_file: must_be_immutable

import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/reports/remote_profit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:mik_components/base/main/mobile.dart';
import 'package:mik_components/elements/fab.dart';

import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/colors.dart';

import '../utils/model.dart';
import '../utils/report.dart';

RxBool chartColumn = false.obs;

class ReportProfit extends GetView {
  var fct;
  RxInt period = 7.obs;
  ReportProfit({super.key});
  RxString tabb = 'هفته'.obs;
  RxBool isFullScreen = false.obs;

  @override
  Widget build(BuildContext context) {
    if (BusinessContext.forApp('mik') != null) return const RemoteProfitReport(appId: 'mik');
    // Analytics.pageView('profitReport');
    return Obx(
      () => !isFullScreen.value
          ? Main(
              floatingActionButton: MyFAB(
                icon: IconsaxPlusLinear.maximize,
                text: 'تمام صفحه',
                onTap: () {
                  isFullScreen.value = true;
                },
              ),
              initState: () async {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.landscapeLeft,
                ]);
                return '';
              },
              header: Obx(
                () => Header.page(
                  context,
                  text: period.value == 1
                      ? 'سود سود روزانه '
                      : period.value == 7
                      ? 'نمودار سود هفتگی '
                      : period.value == 30
                      ? 'نمودار سود ماهانه '
                      : period.value == 90
                      ? 'نمودار سود فصلی '
                      : 'نمودار سود سالانه ',
                  child: SizedBox(
                    width: 340,
                    height: 30,
                    child: Row(
                      children: [
                        MyTab(
                          tab: const ['هفته', 'ماه', 'فصل', 'سال'],
                          value: tabb,
                          width: false,
                          widthSize: 55,
                          height: 50,
                          callback: (c) {
                            tabb.value = c;
                            period.value = c == 'هفته'
                                ? 7
                                : c == 'ماه'
                                ? 30
                                : c == 'فصل'
                                ? 90
                                : 365;
                          },
                        ),
                        const SizedBox(width: 10),
                        Obx(
                          () => BTN(
                            margin: EdgeInsets.zero,
                            borderOnly: true,
                            color: AppColors.secondary,
                            padding: const EdgeInsets.only(right: 5, left: 5),
                            onTap: () => chartColumn.toggle(),
                            name: chartColumn.isFalse
                                ? 'نمودار میله‌ای'
                                : 'نمودار خطی',
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              ),
              child: (c) => Container(
                height: Get.height - 100,
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Obx(
                  () => period.value == 1
                      ? Container()
                      : period.value == 7
                      ? weekChart()
                      : period.value == 30
                      ? monthChart()
                      : period.value == 90
                      ? seasonChart()
                      : yearChart(),
                ),
              ),
            )
          : MainMobile(
              floatingActionButton: MyFAB(
                icon: IconsaxPlusLinear.back_square,
                text: 'بازگشت',
                onTap: () {
                  isFullScreen.value = false;
                },
              ),
              initState: () async {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.landscapeLeft,
                ]);
                return '';
              },
              header: Obx(
                () => Header.page(
                  context,
                  text: period.value == 1
                      ? 'سود سود روزانه '
                      : period.value == 7
                      ? 'نمودار سود هفتگی '
                      : period.value == 30
                      ? 'نمودار سود ماهانه '
                      : period.value == 90
                      ? 'نمودار سود فصلی '
                      : 'نمودار سود سالانه ',
                  child: SizedBox(
                    width: 340,
                    height: 30,
                    child: Row(
                      children: [
                        MyTab(
                          tab: const ['هفته', 'ماه', 'فصل', 'سال'],
                          value: tabb,
                          width: false,
                          widthSize: 55,
                          height: 50,
                          callback: (c) {
                            tabb.value = c;
                            period.value = c == 'هفته'
                                ? 7
                                : c == 'ماه'
                                ? 30
                                : c == 'فصل'
                                ? 90
                                : 365;
                          },
                        ),
                        const SizedBox(width: 10),
                        Obx(
                          () => BTN(
                            margin: EdgeInsets.zero,
                            borderOnly: true,
                            color: AppColors.secondary,
                            padding: const EdgeInsets.only(right: 5, left: 5),
                            onTap: () => chartColumn.toggle(),
                            name: chartColumn.isFalse
                                ? 'نمودار میله‌ای'
                                : 'نمودار خطی',
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              ),
              child: (c) => Container(
                height: Get.height - 100,
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Obx(
                  () => period.value == 1
                      ? Container()
                      : period.value == 7
                      ? weekChart()
                      : period.value == 30
                      ? monthChart()
                      : period.value == 90
                      ? seasonChart()
                      : yearChart(),
                ),
              ),
            ),
    );
  }

  initPage() {}

  weekChart() {
    List<List<SalesData>> data = ReportFX.profitSalesDataInWeek();
    List<SalesData> thisWeek = data.first;
    List<SalesData> lastWeek = data.last;
    return Column(
      children: [
        Expanded(
          child: Obx(
            () => SfCartesianChart(
              primaryXAxis: const CategoryAxis(
                labelStyle: TextStyle(fontFamily: 'raviLight'),
              ),
              primaryYAxis: NumericAxis(
                maximumLabels: 10,
                labelStyle: const TextStyle(fontFamily: 'raviLight'),
                numberFormat: NumberFormat.compact(),
              ),
              enableAxisAnimation: true,
              series: chartColumn.isTrue
                  ? [
                      ColumnSeries<SalesData, String>(
                        dataSource: thisWeek,
                        xValueMapper: (SalesData sales, _) => sales.day,
                        yValueMapper: (SalesData sales, _) => sales.amount,
                        color: AppColors.primary,
                      ),
                      ColumnSeries<SalesData, String>(
                        dataSource: lastWeek,
                        xValueMapper: (SalesData sales, _) => sales.day,
                        yValueMapper: (SalesData sales, _) => sales.amount,
                        color: AppColors.secondary,
                      ),
                    ]
                  : [
                      LineSeries<SalesData, String>(
                        dataSource: thisWeek,
                        xValueMapper: (SalesData sales, _) => sales.day,
                        yValueMapper: (SalesData sales, _) => sales.amount,
                        color: AppColors.primary,
                      ),
                      LineSeries<SalesData, String>(
                        dataSource: lastWeek,
                        xValueMapper: (SalesData sales, _) => sales.day,
                        yValueMapper: (SalesData sales, _) => sales.amount,
                        color: AppColors.secondary,
                      ),
                    ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    height: 1.7,
                    width: 30,
                    color: AppColors.primary,
                  ),
                  const Text('سود این هفته'),
                ],
              ),
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    height: 1.7,
                    width: 30,
                    color: AppColors.secondary,
                  ),
                  const Text('سود هفته گذشته'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  monthChart() {
    List<List<SalesData>> data = ReportFX.profitSalesDataInMonth();
    List<SalesData> thisMonth = data.first;
    List<SalesData> lastMonth = data.last;
    return Column(
      children: [
        Expanded(
          child: SfCartesianChart(
            primaryXAxis: const CategoryAxis(
              labelStyle: TextStyle(fontFamily: 'ravi'),
              labelPlacement: LabelPlacement.onTicks,
            ),
            primaryYAxis: NumericAxis(
              maximumLabels: 10,
              labelStyle: const TextStyle(fontFamily: 'ravi'),
              numberFormat: NumberFormat.compact(),
            ),
            enableAxisAnimation: true,
            series: chartColumn.isTrue
                ? [
                    ColumnSeries<SalesData, String>(
                      dataSource: thisMonth,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.primary,
                    ),
                    ColumnSeries<SalesData, String>(
                      dataSource: lastMonth,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.secondary,
                    ),
                  ]
                : [
                    LineSeries<SalesData, String>(
                      dataSource: thisMonth,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.primary,
                    ),
                    LineSeries<SalesData, String>(
                      dataSource: lastMonth,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.secondary,
                    ),
                  ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    height: 1.7,
                    width: 30,
                    color: AppColors.primary,
                  ),
                  const Text('سود این ماه'),
                ],
              ),
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    height: 1.7,
                    width: 30,
                    color: AppColors.secondary,
                  ),
                  const Text('سود ماه گذشته'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  seasonChart() {
    List<List<SalesData>> data = ReportFX.profitSalesDataInSeason();
    List<SalesData> thisSeason = data.first;
    List<SalesData> lastSeason = data.last;

    return Column(
      children: [
        Expanded(
          child: SfCartesianChart(
            primaryXAxis: const CategoryAxis(
              //labelPlacement: LabelPlacement.onTicks,
              labelStyle: TextStyle(fontFamily: 'ravi'),
            ),
            primaryYAxis: NumericAxis(
              maximumLabels: 10,
              labelStyle: const TextStyle(fontFamily: 'ravi'),
              numberFormat: NumberFormat.compact(),
            ),
            enableAxisAnimation: true,
            series: chartColumn.isTrue
                ? [
                    ColumnSeries<SalesData, String>(
                      dataSource: thisSeason,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.primary,
                    ),
                    ColumnSeries<SalesData, String>(
                      dataSource: lastSeason,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.secondary,
                    ),
                  ]
                : [
                    LineSeries<SalesData, String>(
                      dataSource: thisSeason,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.primary,
                    ),
                    LineSeries<SalesData, String>(
                      dataSource: lastSeason,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.secondary,
                    ),
                  ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    height: 1.7,
                    width: 30,
                    color: AppColors.primary,
                  ),
                  const Text('سود این فصل'),
                ],
              ),
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    height: 1.7,
                    width: 30,
                    color: AppColors.secondary,
                  ),
                  const Text('سود فصل گذشته'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  yearChart() {
    List<List<SalesData>> data = ReportFX.profitSalesDataInYear();
    List<SalesData> thisYear = data.first;
    List<SalesData> lastYear = data.last;
    return Column(
      children: [
        Expanded(
          child: SfCartesianChart(
            primaryXAxis: const CategoryAxis(
              labelStyle: TextStyle(fontFamily: 'ravi'),
            ),
            primaryYAxis: NumericAxis(
              maximumLabels: 10,
              labelStyle: const TextStyle(fontFamily: 'ravi'),
              numberFormat: NumberFormat.compact(),
            ),
            enableAxisAnimation: true,
            series: chartColumn.isTrue
                ? [
                    ColumnSeries<SalesData, String>(
                      dataSource: thisYear,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.primary,
                    ),
                    ColumnSeries<SalesData, String>(
                      dataSource: lastYear,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.secondary,
                    ),
                  ]
                : [
                    LineSeries<SalesData, String>(
                      dataSource: thisYear,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.primary,
                    ),
                    LineSeries<SalesData, String>(
                      dataSource: lastYear,
                      xValueMapper: (SalesData sales, _) => sales.day,
                      yValueMapper: (SalesData sales, _) => sales.amount,
                      color: AppColors.secondary,
                    ),
                  ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    height: 1.7,
                    width: 30,
                    color: AppColors.primary,
                  ),
                  const Text('سود امسال'),
                ],
              ),
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    height: 1.7,
                    width: 30,
                    color: AppColors.secondary,
                  ),
                  const Text('سود سال گذشته'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
