import 'package:mik_variables/permissions.dart';
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/permissionfx.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_utils/private/invoiceStatus.dart';
import 'package:mik_variables/variable.dart';

import 'package:persian_datetime_picker/persian_datetime_picker.dart';

class InvoiceScreenController extends GetxController {
  RxString buy = 'فروش'.obs;
  RxBool change = false.obs;

  RxList fct = [].obs;
  RxList preFct = [].obs;
  RxList fctBuy = [].obs;
  RxList<String> tabList = <String>[].obs;
  RxInt currentIndex = 0.obs;
  RxBool filtered = false.obs;
  Jalali jStartDate = Jalali.now().addDays(-30), jEndDate = Jalali.now();
  RxBool allDate = true.obs;
  RxInt statusfilterSelected = 0.obs;
  RxInt finansialStatusfilterSelected = 0.obs;

  filter(context) {
    bool sell =
        (!(settings!.usePreFactor ?? false) && currentIndex.value == 0) ||
        ((settings!.usePreFactor!) && currentIndex.value == 1);
    bool pre = settings!.usePreFactor! && currentIndex.value == 0;
    MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('بازه زمانی:'),
              Row(
                children: [
                  InkWell(
                    onTap: () async {
                      var d = await showPersianDateRangePicker(
                        initialEntryMode: PersianDatePickerEntryMode.calendar,
                        context: context,
                        firstDate: Jalali.now().addDays(-700),
                        lastDate: Jalali.now(),
                        initialDateRange: JalaliRange(
                          start: jStartDate,
                          end: jEndDate,
                        ),
                        initialDate: jStartDate,
                        barrierColor: Colors.black54,
                        // Jalali.fromDateTime(
                        //     DateTime.now().add(Duration(days: -30)))
                      );
                      if (d != null) {
                        allDate.value = true;
                        jStartDate = d.start;
                        jEndDate = d.end;
                        filtered.value = true;
                        allDate.value = false;
                        init();
                      }
                    },
                    child: Obx(
                      () => allDate.value
                          ? const Text('انتخاب بازه زمانی')
                          : Row(
                              children: [
                                Text(jStartDate.formatCompactDate()),
                                const Text(' - '),
                                Text(jEndDate.formatCompactDate()),
                              ],
                            ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      allDate.value = true;
                      init();
                    },
                    icon: Icon(
                      IconsaxPlusLinear.close_square,
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (sell || pre) MyDivider(),
          if (sell || pre)
            Container(
              alignment: Alignment.centerRight,
              child: const Text('وضعیت:'),
            ),
          if (sell)
            Obx(
              () => Wrap(
                children: [
                  statusItem(
                    'همه',
                    AppColors.backgroundDarkMode,
                    statusfilterSelected.value == 0,
                    () {
                      statusfilterSelected.value = 0;
                      filtered.value = true;
                      init();
                    },
                  ),
                  for (int i = 0; i <= 5; i++)
                    statusItem(
                      InvoiceStatus.nameList[i],
                      InvoiceStatus.color(InvoiceStatus.codeList[i]),
                      statusfilterSelected.value == InvoiceStatus.codeList[i],
                      () {
                        statusfilterSelected.value = InvoiceStatus.codeList[i];
                        filtered.value = true;
                        init();
                      },
                    ),
                ],
              ),
            ),
          if (pre)
            Obx(
              () => Wrap(
                children: [
                  statusItem(
                    'همه',
                    AppColors.backgroundDarkMode,
                    statusfilterSelected.value == 0,
                    () {
                      statusfilterSelected.value = 0;
                      filtered.value = true;
                      init();
                    },
                  ),
                  for (int i = 6; i <= 7; i++)
                    statusItem(
                      InvoiceStatus.nameList[i],
                      InvoiceStatus.color(InvoiceStatus.codeList[i]),
                      statusfilterSelected.value == InvoiceStatus.codeList[i],
                      () {
                        statusfilterSelected.value = InvoiceStatus.codeList[i];
                        filtered.value = true;
                        init();
                      },
                    ),
                ],
              ),
            ),
          if (!pre) MyDivider(),
          if (!pre)
            Container(
              alignment: Alignment.centerRight,
              child: const Text('وضعیت تسویه:'),
            ),
          if (!pre)
            Obx(
              () => Wrap(
                children: [
                  statusItem(
                    'همه',
                    AppColors.backgroundDarkMode,
                    finansialStatusfilterSelected.value == 0,
                    () {
                      finansialStatusfilterSelected.value = 0;
                      filtered.value = true;
                      init();
                    },
                  ),
                  statusItem(
                    'تسویه شده',
                    AppColors.backgroundDarkMode,
                    finansialStatusfilterSelected.value == 1,
                    () {
                      finansialStatusfilterSelected.value = 1;
                      filtered.value = true;
                      init();
                    },
                  ),
                  statusItem(
                    'تسویه نشده',
                    AppColors.backgroundDarkMode,
                    finansialStatusfilterSelected.value == 2,
                    () {
                      finansialStatusfilterSelected.value = 2;
                      filtered.value = true;
                      init();
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 30),
          Row(
            children: [
              Flexible(
                child: BTN(
                  borderOnly: true,
                  color: darkMode.isFalse
                      ? AppColors.backgroundDarkMode
                      : AppColors.backgroundDarkMode,
                  icon: null,
                  onTap: () {
                    Get.back();
                  },
                  navigate: true,
                  name: 'بستن',
                ),
              ),
              Flexible(
                child: BTN(
                  type: BTNType.cancel,
                  onTap: () {
                    statusfilterSelected.value = 0;
                    allDate.value = true;
                    jStartDate = Jalali.now().addDays(-30);
                    jEndDate = Jalali.now();
                    filtered.value = false;
                    init();
                    Get.back();
                  },
                  name: 'حذف همه فیلتر‌ها',
                ),
              ),
            ],
          ),
        ],
      ),
      title: 'فیلتر نمایش فاکتورها',

      // h: sell
      //     ? 290
      //     : pre
      //         ? 250
      //         : 170
    );
  }

  statusItem(name, Color color, bool selected, callback) {
    return Container(
      margin: const EdgeInsets.all(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => callback(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: darkMode.value ? Colors.white : Colors.black,
            ), //color),
            color: selected
                ? darkMode.value
                      ? Colors.white
                      : Colors.black
                : null, //color.withValues(alpha: 0.2),
          ),
          child: Text(
            name,
            style: TextStyle(
              color: selected
                  ? !darkMode.value
                        ? Colors.white
                        : Colors.black
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  init() async {
    await Future.delayed(Duration(seconds: 1));

    tabList.value = [];
    if ((settings!.usePreFactor ?? false) &&
        !tabList.contains('پیش‌فاکتور') &&
        (PermissionAccess.hasPermission(PermissionsName.invoicesPreView) || PermissionAccess.hasPermission(PermissionsName.invoicesPreViewAll))) {
      if (currentIndex.isNull) {
        currentIndex = 1.obs;
      }

      tabList.value = ['پیش‌فاکتور', ...tabList];
    } else {
      if (currentIndex.isNull) {
        currentIndex = 0.obs;
      }
    }
    if (PermissionAccess.hasPermission(PermissionsName.invoicesSellView) || PermissionAccess.hasPermission(PermissionsName.invoicesSellViewAll)) {
      tabList.add('فروش');
    }
    if (PermissionAccess.hasPermission(PermissionsName.invoicesBuyView) || PermissionAccess.hasPermission(PermissionsName.invoicesBuyViewAll)) {
      tabList.add('خرید');
    }

    if ((!(settings!.usePreFactor ?? false) && currentIndex.value == 0) ||
        (settings!.usePreFactor! && currentIndex.value == 1)) {
      fct.value = invoice.values
          .where(
            (element) =>
                element.type != 'buy' &&
                element.status!.every(
                  (t) => t['status'] < 900 && t['status'] != 444,
                ) &&
                (statusfilterSelected.value != 0
                    ? InvoiceStatus.findLastStatusCode(element.status!) ==
                          statusfilterSelected.value
                    : true) &&
                (allDate.isFalse
                    ? (DateTime.parse(element.date!)
                              .isBefore(jEndDate.toDateTime()) &&
                          DateTime.parse(element.date!)
                              .isAfter(jStartDate.toDateTime()))
                    : true) &&
                (finansialStatusfilterSelected.value == 0
                    ? true
                    : finansialStatusfilterSelected.value == 1
                    ? InvoiceFX.isPaid(element.billUID ?? [])
                    : !InvoiceFX.isPaid(element.billUID ?? [])),
          )
          .toList();
    }
    if (settings!.usePreFactor != null && settings!.usePreFactor!) {
      preFct.value = invoice.values
          .where(
            (element) =>
                element.type != 'buy' &&
                element.status!.every((t) => t['status'] >= 900) &&
                (statusfilterSelected.value != 0
                    ? InvoiceStatus.findLastStatusCode(element.status!) ==
                          statusfilterSelected.value
                    : true) &&
                (allDate.isFalse
                    ? (DateTime.parse(element.date!)
                              .isBefore(jEndDate.toDateTime()) &&
                          DateTime.parse(element.date!)
                              .isAfter(jStartDate.toDateTime()))
                    : true),
          )
          .toList();
    }
    if ((!(settings!.usePreFactor ?? false) && currentIndex.value == 1) ||
        (settings!.usePreFactor! && currentIndex.value == 2)) {
      fctBuy.value = invoice.values
          .where(
            (element) =>
                element.type == 'buy' &&
                element.status!.every((t) => t['status'] != 444) &&
                (allDate.isFalse
                    ? (DateTime.parse(element.date!)
                              .isBefore(jEndDate.toDateTime()) &&
                          DateTime.parse(element.date!)
                              .isAfter(jStartDate.toDateTime()))
                    : true) &&
                (finansialStatusfilterSelected.value == 0
                    ? true
                    : finansialStatusfilterSelected.value == 1
                    ? InvoiceFX.isPaid(element.billUID ?? [])
                    : !InvoiceFX.isPaid(element.billUID ?? [])),
          )
          .toList();
    }
    // fct.sort((a, b) => b.id.compareTo(
    //     a.id)); //DateTime.parse(b.date!).compareTo(DateTime.parse(a.date!)));
    // preFct.sort((a, b) => b.id.compareTo(a.id));
    // fctBuy.sort((a, b) => b.id.compareTo(
    //     a.id)); //DateTime.parse(b.date!).compareTo(DateTime.parse(a.date!)));
    print('b');
    fct.sort((a, b) {
      print('a : ${a.date}');
      print('b : ${b.date}');
      return DateTime.parse(b.date).compareTo(DateTime.parse(a.date));
    });
    preFct.sort(
      (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)),
    );
    fctBuy.sort(
      (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)),
    );

    fctBuy.value = fctBuy
        .where((f) => PermissionFx.isShowFactorItem(f))
        .toList();
    fct.value = fct.where((f) => PermissionFx.isShowFactorItem(f)).toList();
    return '';
  }
}
