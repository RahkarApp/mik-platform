// ignore_for_file: must_be_immutable

import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/reports/quantity_unavailable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/myTextScroll.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_utils/public/number.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_data/models/models.dart';

import '../../utils/report.dart';

class ReportProductsCount extends GetView {
  var productItem = [];
  RxString type = 'همه'.obs;
  RxInt currentIndex = 0.obs;
  RxList productItemFilter = [].obs;
  String search = '';
  String searchCat = '';
  final searchCatIDCtl = TextEditingController();
  RxBool change = false.obs, catSel = false.obs;
  var startDate;
  var endDate;
  RxBool startDateSelected = false.obs;
  final startDateCtl = TextEditingController();
  final endDateCtl = TextEditingController();
  RxBool dateRange = false.obs, itemReverse = false.obs;
  Jalali jStartDate = Jalali.now().addDays(-30), jEndDate = Jalali.now();
  ReportProductsCount({super.key});
  @override
  Widget build(BuildContext context) {
    if (BusinessContext.forApp('mik') != null) return const QuantityReportUnavailable(appId: 'mik');
    // Analytics.pageView('productReportList');
    return Main(
      initState: () async => await initPage(),
      header: Header.page(context, text: 'گزارش گردش تعدادی'),
      child: (d) => Obx(
        () => Column(
          children: [
            const SizedBox(height: 10),
            if (profile.getAt(0)!.type!.length > 1)
              // MyTab(
              //     tab: const ['همه', 'محصولات', 'خدمات'],
              //     value: type,
              //     callback: (v) {
              //       type.value = v;
              //       initPage();
              //     }),
              MyTabBar(
                tabs: const ['همه', 'محصولات', 'خدمات'],
                divider: false,
                currentIndex: currentIndex.value,
                index: (i) {
                  currentIndex.value = i;
                  i == 0
                      ? type.value = 'همه'
                      : i == 1
                      ? type.value = 'محصولات'
                      : type.value = 'خدمات';
                },
              ),
            const SizedBox(height: 5),
            Row(
              children: [
                Flexible(
                  child: MySearchBar(
                    type: SearchBarType.product,
                    callback: (v) {
                      search = v;
                      filter();
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => sortItem(),
                  icon: const Icon(IconsaxPlusLinear.filter),
                ),
                IconButton(
                  onPressed: () => sortItemReverse(),
                  icon: Obx(
                    () => Transform.flip(
                      flipX: itemReverse.isTrue,
                      child: const Icon(IconsaxPlusLinear.arrow_swap),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.only(right: 10, left: 8, bottom: 8),
              child: Row(
                children: [
                  Flexible(
                    child: Obx(
                      () => BTN(
                        onTap: () async {
                          var d = await showPersianDateRangePicker(
                            initialEntryMode: PersianDatePickerEntryMode.input,

                            context: context,
                            firstDate: Jalali.now().addDays(-700),
                            lastDate: Jalali.now(),
                            initialDateRange: JalaliRange(
                              start: jStartDate,
                              end: jEndDate,
                            ),
                            initialDate: Jalali.fromDateTime(
                              DateTime.now().add(Duration(days: -30)),
                            ),
                          );

                          if (d != null) {
                            dateRange.value = false;
                            dateRange.value = true;
                            jStartDate = d.start;
                            jEndDate = d.end;
                            startDate = jStartDate.toDateTime();
                            endDate = jEndDate.toDateTime();
                            initPage();
                          }
                        },
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        borderOnly: true,
                        color: darkMode.value ? Colors.grey : AppColors.primary,
                        name: !dateRange.value
                            ? 'انتخاب بازه زمانی'
                            : '${jStartDate.formatCompactDate()} - ${jEndDate.formatCompactDate()}',
                      ), // '${jStartDate.formatCompactDate()} - ${jEndDate.formatCompactDate()}'),
                    ),
                  ),
                  Obx(
                    () => dateRange.value
                        ? IconButton(
                            onPressed: () {
                              dateRange.value = false;
                              initPage();
                            },
                            icon: Icon(
                              IconsaxPlusLinear.close_square,
                              color: AppColors.grey,
                              size: 35,
                            ),
                          )
                        : Container(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(
                () => productItemFilter.isNotEmpty
                    ? ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: productItemFilter.length,
                        itemBuilder: (BuildContext context, int i) {
                          return showItemNew(
                            context,
                            item: productItemFilter[i],
                            end: productItemFilter.length == i + 1,
                          );
                        },
                      )
                    : EmptyList(
                        text: 'چیزی وجود ندارد!!',
                        icon: IconsaxPlusLinear.box_search,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  showItemNew(context, {item, bool? end}) {
    return type.value == 'همه' ||
            (type.value != 'همه' &&
                item['type'] ==
                    (type.value == 'محصولات' ? 'product' : 'service'))
        ? Column(
            children: [
              InkWell(
                onTap: () async {
                  await Get.toNamed(
                    RoutesName.REPORTSPRODUCTCOUNTDETAIL,
                    arguments: {'productUID': item['uid']},
                  );
                  await SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                  ]);
                },
                child: Container(
                  padding: const EdgeInsets.only(
                    right: 20,
                    left: 10,
                    top: 5,
                    bottom: 5,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            // width: Get.width * 0.4,
                            child: MyTextScroll(
                              item['name'],
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text('آخرین فروش: ${item['stoke']['lastSell']}'),
                        ],
                      ),
                      if (item['type'] == null ||
                          (item['type'] != null && item['type'] != 'service'))
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: Get.width / 6,
                              alignment: Alignment.centerRight,
                              child: const Text('خرید: '),
                            ),
                            Flexible(
                              child: Text(
                                item['buyItem']['factor'] > 0
                                    ? '${item['buyItem']['factor']} فاکتور / ${item['buyItem']['amount']} واحد'
                                    : '---',
                              ),
                            ),
                            Container(
                              width: Get.width / 5,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                Number.addCommas(item['buyItem']['price']),
                              ),
                            ),
                          ],
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: Get.width / 6,
                            alignment: Alignment.centerRight,
                            child: const Text('فروش: '),
                          ),
                          Flexible(
                            child: Text(
                              item['sellItem']['factor'] > 0
                                  ? '${item['sellItem']['factor']} فاکتور / ${item['sellItem']['amount']} واحد'
                                  : '---',
                            ),
                          ),
                          Container(
                            width: Get.width / 5,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              Number.addCommas(item['sellItem']['price']),
                            ),
                          ),
                        ],
                      ),
                      if (item['type'] == null ||
                          (item['type'] != null && item['type'] != 'service'))
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'موجودی: ${Number.addCommas(item['stoke']['stoke'])}',
                            ),
                            Text(
                              'ارزش موجودی: ${Price.show(item['stoke']['stokePrice'])}',
                            ),
                          ],
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('سود: ${Price.show(item['stoke']['profit'])}'),
                          if (item['type'] == null ||
                              (item['type'] != null &&
                                  item['type'] != 'service'))
                            Text(
                              'سود موجودی: ${Price.show(item['stoke']['nextProfit']).split('.')[0]}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              EndLine(show: !end!),
            ],
          )
        : Container();
  }

  initPage() async {
    productItem = [];
    productItemFilter.value = [];

    for (var i = 0; i < product.length; i++) {
      productItem.add(product.getAt(i)!.toJson());

      List<InvoiceDB> itemBuyFactor = ReportFX.findBuyInvoice(
        productItem[i]['uid'],
        startDate: dateRange.isTrue ? startDate : null,
        endDate: dateRange.isTrue ? endDate : null,
      );

      List<InvoiceDB> itemSellFactor = ReportFX.findSellInvoice(
        productItem[i]['uid'],
        startDate: dateRange.isTrue ? startDate : null,
        endDate: dateRange.isTrue ? endDate : null,
      );

      List<InvoiceDB> itemSellCancellFactor = ReportFX.findCancellInvoice(
        productItem[i]['uid'],
        startDate: dateRange.isTrue ? startDate : null,
        endDate: dateRange.isTrue ? endDate : null,
      );

      List<InvoiceDB> itemSellRejectFactor = ReportFX.findRejectInvoice(
        productItem[i]['uid'],
        startDate: dateRange.isTrue ? startDate : null,
        endDate: dateRange.isTrue ? endDate : null,
      );

      productItem[i]['buyItem'] = {
        "factor": itemBuyFactor.length,
        'amount': ReportFX.findAmountInInvoice(
          itemBuyFactor,
          productItem[i]['uid'],
        ),
        'price': ReportFX.findPriceInInvoice(
          itemBuyFactor,
          true,
          productItem[i]['uid'],
        ),
      };

      productItem[i]['sellItem'] = {
        "factor": itemSellFactor.length,
        'amount': ReportFX.findAmountInInvoice(
          itemSellFactor,
          productItem[i]['uid'],
        ),
        'price': ReportFX.findPriceInInvoice(
          itemSellFactor,
          false,
          productItem[i]['uid'],
        ),
      };

      productItem[i]['sellCancellItem'] = {
        "factor": itemSellCancellFactor.length,
        'amount': ReportFX.findAmountInInvoice(
          itemSellCancellFactor,
          productItem[i]['uid'],
        ),
        'price': ReportFX.findPriceInInvoice(
          itemSellCancellFactor,
          false,
          productItem[i]['uid'],
        ),
      };

      productItem[i]['sellRejectItem'] = {
        "factor": itemSellRejectFactor.length,
        'amount': ReportFX.findAmountInInvoice(
          itemSellRejectFactor,
          productItem[i]['uid'],
        ),
        'price': ReportFX.findPriceInInvoice(
          itemSellRejectFactor,
          false,
          productItem[i]['uid'],
        ),
      };

      var stoke = ReportFX.productDetail(
        productItem[i]['uid'],
        start: startDate,
        end: endDate,
      );

      productItem[i]['stoke'] = {
        'stoke': stoke['inv'],
        'stokePrice':
            stoke['inv'] * AccountingFX.productSellPrice(productItem[i]['uid']),
        'profit': stoke['profit'],
        'nextProfit':
            (AccountingFX.productSellPrice(productItem[i]['uid']) -
                stoke['buyPrice']) *
            stoke['inv'],
        'lastSellG': stoke['lastSellDateG'] != '-'
            ? stoke['lastSellDateG']
            : "1969-07-20 20:18:04Z",
        'lastSell': stoke['lastSellDate'],
      };
    }

    if (dateRange.isFalse) {
      productItemFilter.value = productItem;
    } else if (dateRange.isTrue) {
      for (var x = 0; x < productItem.length; x++) {
        if (productItem[x]['sellItem']['amount'] > 0 ||
            productItem[x]['buyItem']['amount'] > 0) {
          productItemFilter.add(productItem[x]);
        }
      }
    }

    return '';
  }

  bool checkDate(date) {
    if (dateRange.isFalse) {
      return true;
    } else if (dateRange.isTrue && date != null) {
      return DateTime.parse(date.replaceAll("T", ' ').replaceAll("Z", ''))
              .isBefore(endDate!) &&
          DateTime.parse(date.replaceAll("T", ' ').replaceAll("Z", ''))
              .isAfter(startDate!);
    }
    return false;
  }

  sortItem() {
    //UnUsed
    Get.defaultDialog(
      radius: 10.0,
      backgroundColor: darkMode.isFalse ? Colors.white : Colors.grey.shade700,
      title: 'مرتب سازی بر اساس',
      content: Column(
        children: [
          BTN(
            onTap: () {
              productItemFilter.sort(
                (a, b) =>
                    DateTime.parse(b['stoke']['lastSellG'])
                        .compareTo(DateTime.parse(a['stoke']['lastSellG'])),
              );
              Get.back();
            },
            name: 'تاریخ فروش',
            borderOnly: true,
            color: darkMode.isTrue ? Colors.white : AppColors.primary,
          ),
          BTN(
            onTap: () {
              productItemFilter.sort(
                (a, b) =>
                    b['sellItem']['amount'].compareTo(a['sellItem']['amount']),
              );
              Get.back();
            },
            name: 'تعداد فروش',
            borderOnly: true,
            color: darkMode.isTrue ? Colors.white : AppColors.primary,
          ),
          BTN(
            onTap: () {
              productItemFilter.sort(
                (a, b) =>
                    b['sellItem']['price'].compareTo(a['sellItem']['price']),
              );
              Get.back();
            },
            name: 'مبلغ فروش',
            borderOnly: true,
            color: darkMode.isTrue ? Colors.white : AppColors.primary,
          ),
          BTN(
            onTap: () {
              productItemFilter.sort(
                (a, b) => b['stoke']['stoke'].compareTo(a['stoke']['stoke']),
              );
              Get.back();
            },
            name: 'موجودی محصول',
            borderOnly: true,
            color: darkMode.isTrue ? Colors.white : AppColors.primary,
          ),
          BTN(
            onTap: () {
              productItemFilter.sort(
                (a, b) => b['stoke']['profit'].compareTo(a['stoke']['profit']),
              );
              Get.back();
            },
            name: 'سود',
            borderOnly: true,
            color: darkMode.isTrue ? Colors.white : AppColors.primary,
          ),
          BTN(
            onTap: () {
              productItemFilter.sort(
                (a, b) => b['sellCancellItem']['amount'].compareTo(
                  a['sellCancellItem']['amount'],
                ),
              );
              Get.back();
            },
            name: 'لغوی سفارش',
            borderOnly: true,
            color: darkMode.isTrue ? Colors.white : AppColors.primary,
          ),
          BTN(
            onTap: () {
              productItemFilter.sort(
                (a, b) => b['sellRejectItem']['amount'].compareTo(
                  a['sellRejectItem']['amount'],
                ),
              );
              Get.back();
            },
            name: 'مرجوعی سفارش',
            borderOnly: true,
            color: darkMode.isTrue ? Colors.white : AppColors.primary,
          ),
        ],
      ),
    );
  }

  sortItemReverse() {
    productItemFilter.value = List.from(productItemFilter.reversed);
    itemReverse.toggle();
  }

  filter() {
    var filtter = [];
    var prList = [];
    int prSize = productItem.length;
    if (searchCatIDCtl.text.isNotEmpty) {
      catSel.value = true;
      for (var i = 0; i < prSize; i++) {
        var it = productItem[i];
        if (it['categoryID'] == int.parse(searchCatIDCtl.text)) {
          prList.add(it);
        }
      }
    } else {
      prList = productItem;
    }
    if (search.isNotEmpty) {
      for (var i = 0; i < prList.length; i++) {
        var it = prList[i];
        if (it['name'].contains(s)) {
          filtter.add(it);
        }
      }
      productItemFilter.value = filtter;
    } else {
      productItemFilter.value = prList;
    }
  }
}
