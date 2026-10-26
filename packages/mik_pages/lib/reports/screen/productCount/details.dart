// ignore_for_file: must_be_immutable

import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/reports/quantity_unavailable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:mik_components/base/main/mobile.dart';
import 'package:mik_components/elements/fab.dart';

import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:mik_data/utils/variable.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_consts/const.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_utils/public/date.dart';

import '../../utils/model.dart';
import '../../utils/report.dart';

RxBool chartColumn = false.obs;

class ReportProductsCountDetails extends GetView {
  String? productUID;
  ReportProductsCountDetails({super.key, this.productUID});
  var fct;
  RxInt period = 7.obs;
  RxString tabb = 'هفته'.obs;
  RxBool isFullScreen = false.obs;
  @override
  Widget build(BuildContext context) {
    if (BusinessContext.forApp('mik') != null) return const QuantityReportUnavailable(appId: 'mik');
    initPage(context);
    var prd = product.values
        .where((element) => element.uid == productUID)
        .toList()[0];
    // Analytics.pageView('productReport');
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
              initState: () async => await initPage(context),
              header: Obx(
                () => Header.page(
                  context,
                  text: period.value == 1
                      ? 'فروش روزانه ${prd.name!}'
                      : period.value == 7
                      ? 'نمودار فروش هفتگی ${prd.name!}'
                      : period.value == 30
                      ? 'نمودار فروش ماهانه ${prd.name!}'
                      : period.value == 90
                      ? 'نمودار فروش فصلی ${prd.name!}'
                      : 'نمودار فروش سالانه ${prd.name!}',
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
                  () => darkMode.isFalse || darkMode.isTrue
                      ? period.value == 1
                            ? Container()
                            : period.value == 7
                            ? weekChart()
                            : period.value == 30
                            ? monthChart()
                            : period.value == 90
                            ? seasonChart()
                            : yearChart()
                      : Container(),
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
              initState: () async => await initPage(context),
              header: Obx(
                () => Header.page(
                  context,
                  text: period.value == 1
                      ? 'فروش روزانه ${prd.name!}'
                      : period.value == 7
                      ? 'نمودار فروش هفتگی ${prd.name!}'
                      : period.value == 30
                      ? 'نمودار فروش ماهانه ${prd.name!}'
                      : period.value == 90
                      ? 'نمودار فروش فصلی ${prd.name!}'
                      : 'نمودار فروش سالانه ${prd.name!}',
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
                  () => darkMode.isFalse || darkMode.isTrue
                      ? period.value == 1
                            ? Container()
                            : period.value == 7
                            ? weekChart()
                            : period.value == 30
                            ? monthChart()
                            : period.value == 90
                            ? seasonChart()
                            : yearChart()
                      : Container(),
                ),
              ),
            ),
    );
  }

  initPage(context) async {
    // topPadding = 0;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    //topPadding = MediaQuery.of(context).viewPadding.top;
    fct = ReportFX.findAllInvoice(productUID!);

    return '';
  }

  weekChart() {
    List<SalesData> thisWeek = [];
    List<SalesData> lastWeek = [];
    List dateDayWeek = [];
    List dateDayLastWeek = [];

    for (var i = Jalali.now().weekDay - 1; i > 0; i--) {
      dateDayWeek.add(
        DateTime.now().add(Duration(days: -i)).toPersianDate().toEnglishDigit(),
      );
      dateDayLastWeek.add(
        DateTime.now()
            .add(Duration(days: -i - 7))
            .toPersianDate()
            .toEnglishDigit(),
      );
    }

    dateDayWeek.add(DateTime.now().toPersianDate().toEnglishDigit());
    dateDayLastWeek.add(
      DateTime.now()
          .add(const Duration(days: -7))
          .toPersianDate()
          .toEnglishDigit(),
    );

    for (var i = 1; i <= (7 - Jalali.now().weekDay); i++) {
      dateDayWeek.add(
        DateTime.now().add(Duration(days: i)).toPersianDate().toEnglishDigit(),
      );
      dateDayLastWeek.add(
        DateTime.now()
            .add(Duration(days: i - 7))
            .toPersianDate()
            .toEnglishDigit(),
      );
    }

    for (var d = 0; d < 7; d++) {
      var dd = dateDayWeek[d].split('/');
      var dateG = DateConvertor.jalaliToGrigori(dateDayWeek[d]);
      num amount = 0;
      for (var i = 0; i < fct.length; i++) {
        if (fct[i].type != 'buy' &&
            fct[i].status!.every(
              (e) =>
                  e['status'] != null &&
                  (e['status'] < 8 || e['status'] == 100),
            ) &&
            DateTime.parse(fct[i].date!.split('T')[0])
                    .compareTo(DateTime.parse(dateG.split('T')[0])) ==
                0) {
          print('${fct[i].items[productUID]}');
          for (var pro in fct[i].items[productUID]) {
            amount += pro['amount'];
          }

          // amount += fct[i].amount[fct[i].productUID.indexOf(productUID)];
        }
      }
      thisWeek.add(
        SalesData(
          ReportFX.day(
            Jalali(
              int.parse(dd[0]),
              int.parse(dd[1]),
              int.parse(dd[2]),
            ).weekDay,
          ),
          amount,
        ),
      );
    }

    for (var d = 0; d < 7; d++) {
      var dd = dateDayLastWeek[d].split('/');
      var dateG = DateConvertor.jalaliToGrigori(dateDayLastWeek[d]);
      num amount = 0;
      for (var i = 0; i < fct.length; i++) {
        if (fct[i].type != 'buy' &&
            fct[i].status!.every(
              (e) =>
                  e['status'] != null &&
                  (e['status'] < 8 || e['status'] == 100),
            ) &&
            DateTime.parse(fct[i].date!.split('T')[0])
                    .compareTo(DateTime.parse(dateG.split('T')[0])) ==
                0) {
          for (var pro in fct[i].items[productUID]) {
            amount += pro['amount'];
          }
        }
      }
      lastWeek.add(
        SalesData(
          ReportFX.day(
            Jalali(
              int.parse(dd[0]),
              int.parse(dd[1]),
              int.parse(dd[2]),
            ).weekDay,
          ),
          amount,
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Obx(
            () => SfCartesianChart(
              primaryXAxis: const CategoryAxis(
                labelStyle: TextStyle(fontFamily: 'ravi'),
              ),
              primaryYAxis: const NumericAxis(
                labelStyle: TextStyle(fontFamily: 'ravi'),
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
                  const Text('فروش این هفته'),
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
                  const Text('فروش هفته گذشته'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  monthChart() {
    List<SalesData> thisMonth = [];
    List<SalesData> lastMonth = [];
    int thisMonthNum = Jalali.now().month;

    int lastMonthNum = thisMonthNum > 1 ? thisMonthNum - 1 : 12;
    int lastYear = Jalali.now().year - 1;
    for (var d = 1; d < Jalali.now().monthLength + 1; d++) {
      num amount = 0;
      for (var i = 0; i < fct.length; i++) {
        if (fct[i].type != 'buy' &&
            fct[i].status!.every(
              (e) =>
                  e['status'] != null &&
                  (e['status'] < 8 || e['status'] == 100),
            ) &&
            Jalali.fromDateTime(DateTime.parse(fct[i].date)).month ==
                thisMonthNum &&
            Jalali.fromDateTime(DateTime.parse(fct[i].date)).day == d) {
          for (var pro in fct[i].items[productUID]) {
            amount += pro['amount'];
          }
        }
      }
      thisMonth.add(SalesData(d.toString(), amount));
    }

    for (var d = 1; d < Jalali.now().monthLength + 1; d++) {
      num amount = 0;
      for (var i = 0; i < fct.length; i++) {
        if (fct[i].type != 'buy' &&
            fct[i].status!.every(
              (e) =>
                  e['status'] != null &&
                  (e['status'] < 8 || e['status'] == 100),
            ) &&
            Jalali.fromDateTime(DateTime.parse(fct[i].date)).month ==
                lastMonthNum &&
            Jalali.fromDateTime(DateTime.parse(fct[i].date)).day == d) {
          if (lastMonthNum == 12 &&
              Jalali.fromDateTime(DateTime.parse(fct[i].date)).year ==
                  lastYear) {
            for (var pro in fct[i].items[productUID]) {
              amount += pro['amount'];
            }
          } else if (lastMonthNum < 12) {
            for (var pro in fct[i].items[productUID]) {
              amount += pro['amount'];
            }
          }
        }
      }
      lastMonth.add(SalesData(d.toString(), amount));
    }

    return Column(
      children: [
        Expanded(
          child: Obx(
            () => SfCartesianChart(
              primaryXAxis: const CategoryAxis(
                labelStyle: TextStyle(fontFamily: 'ravi'),
                labelPlacement: LabelPlacement.onTicks,
              ),
              primaryYAxis: NumericAxis(
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
                  const Text('فروش این ماه'),
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
                  const Text('فروش ماه گذشته'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  seasonChart() {
    List<SalesData> thisSeason = [];
    List<SalesData> lastSeason = [];
    const offsets = [0, 31, 62, 93, 124, 155, 185, 215, 245, 275, 305, 335];
    int week = (offsets[Jalali.now().month - 1] + Jalali.now().day) ~/ 7;
    int thisSeasonNum = week < 13
        ? 1
        : week > 12 && week < 25
        ? 2
        : week <= 36
        ? 3
        : 4;
    List seasonWeek = [
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
      [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26],
      [27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39],
      [40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52],
    ];
    int lastSeasonNum = thisSeasonNum > 2 ? thisSeasonNum - 1 : 4;
    int lastYear = Jalali.now().year - 1;
    for (var d = 1; d < 14; d++) {
      num amount = 0;
      for (var i = 0; i < fct.length; i++) {
        if (fct[i].type != 'buy' &&
            fct[i].status!.every(
              (e) =>
                  e['status'] != null &&
                  (e['status'] < 8 || e['status'] == 100),
            ) &&
            seasonWeek[thisSeasonNum - 1].contains(
              (offsets[Jalali.fromDateTime(DateTime.parse(fct[i].date)).month -
                          1] +
                      Jalali.now().day) ~/
                  7,
            ) &&
            ((offsets[Jalali.now().month - 1] + Jalali.now().day) ~/ 7) ==
                seasonWeek[thisSeasonNum - 1][d - 1]) {
          for (var pro in fct[i].items[productUID]) {
            amount += pro['amount'];
          }
        }
      }
      thisSeason.add(SalesData('هفته $d', amount));
    }

    for (var d = 1; d < 13; d++) {
      num amount = 0;
      for (var i = 0; i < fct.length; i++) {
        if (fct[i].type != 'buy' &&
            fct[i].status!.every(
              (e) =>
                  e['status'] != null &&
                  (e['status'] < 8 || e['status'] == 100),
            ) &&
            seasonWeek[lastSeasonNum - 1].contains(
              (offsets[Jalali.fromDateTime(DateTime.parse(fct[i].date)).month -
                          1] +
                      Jalali.now().day) ~/
                  7,
            ) &&
            ((offsets[Jalali.now().month - 1] + Jalali.now().day) ~/ 7) ==
                seasonWeek[lastSeasonNum - 1][d - 1]) {
          if (lastSeasonNum == 4 &&
              Jalali.fromDateTime(DateTime.parse(fct[i].date)).year ==
                  lastYear) {
            for (var pro in fct[i].items[productUID]) {
              amount += pro['amount'];
            }
          } else if (lastSeasonNum < 4) {
            for (var pro in fct[i].items[productUID]) {
              amount += pro['amount'];
            }
          }
        }
      }
      lastSeason.add(SalesData('هفته $d', amount));
    }

    return Column(
      children: [
        Expanded(
          child: Obx(
            () => SfCartesianChart(
              primaryXAxis: const CategoryAxis(
                labelStyle: TextStyle(fontFamily: 'ravi'),
              ),
              primaryYAxis: NumericAxis(
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
                  const Text('فروش این فصل'),
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
                  const Text('فروش فصل گذشته'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  yearChart() {
    List<SalesData> thisYear = [];
    List<SalesData> lastYear = [];
    int thisYearNum = Jalali.now().year;

    int lastYearNum = thisYearNum - 1;
    for (var d = 1; d < 13; d++) {
      num amount = 0;
      for (var i = 0; i < fct.length; i++) {
        if (fct[i].type != 'buy' &&
            fct[i].status!.every(
              (e) =>
                  e['status'] != null &&
                  (e['status'] < 8 || e['status'] == 100),
            ) &&
            Jalali.fromDateTime(DateTime.parse(fct[i].date)).year ==
                thisYearNum &&
            Jalali.fromDateTime(DateTime.parse(fct[i].date)).month == d) {
          for (var pro in fct[i].items[productUID]) {
            amount += pro['amount'];
          }
        }
      }
      thisYear.add(SalesData(months[d - 1], amount));
    }

    for (var d = 1; d < 13; d++) {
      num amount = 0;
      for (var i = 0; i < fct.length; i++) {
        if (fct[i].type != 'buy' &&
            fct[i].status!.every(
              (e) =>
                  e['status'] != null &&
                  (e['status'] < 8 || e['status'] == 100),
            ) &&
            Jalali.fromDateTime(DateTime.parse(fct[i].date)).year ==
                lastYearNum &&
            Jalali.fromDateTime(DateTime.parse(fct[i].date)).month == d) {
          for (var pro in fct[i].items[productUID]) {
            amount += pro['amount'];
          }
        }
      }
      lastYear.add(SalesData(months[d - 1], amount));
    }

    return Column(
      children: [
        Expanded(
          child: Obx(
            () => SfCartesianChart(
              primaryXAxis: const CategoryAxis(
                labelStyle: TextStyle(fontFamily: 'ravi'),
              ),
              primaryYAxis: NumericAxis(
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
                  const Text('فروش امسال'),
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
                  const Text('فروش سال گذشته'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
