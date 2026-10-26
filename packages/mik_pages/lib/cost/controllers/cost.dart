import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/myTab.dart';

import 'package:mik_consts/colors.dart';
import 'package:mik_data/utils/fx/cost.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_variables/variable.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';


class CostScreenController extends GetxController {
  List costList = [];
  List shippingCostList = [];
  RxBool change = false.obs;
  RxInt currentIndex = 0.obs;
  RxString costType = 'هزینه‌ها'.obs;

  RxBool filtered = false.obs;
  Jalali jStartDate = Jalali.now().addDays(-30), jEndDate = Jalali.now();
  RxBool allDate = true.obs;
  RxString filterStatus = 'همه'.obs;
  filter(context) {
    MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        children: [
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('بازه زمانی:'),
              Row(
                children: [
                  InkWell(
                    onTap: () async {
                      var d = await showPersianDateRangePicker(
                        //showEntryModeIcon: true,
                        initialEntryMode: PersianDatePickerEntryMode.calendar,
                        context: context,
                        firstDate: Jalali.now().addDays(-700),
                        lastDate: Jalali.now(),
                        initialDateRange: JalaliRange(start: jStartDate, end: jEndDate),
                        initialDate: Jalali.fromDateTime(DateTime.now().add(Duration(days: -30))),
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
                    child: Obx(() => allDate.value ? const Text('انتخاب بازه زمانی') : Row(children: [Text(jStartDate.formatCompactDate()), const Text(' - '), Text(jEndDate.formatCompactDate())])),
                  ),
                  IconButton(
                    onPressed: () {
                      allDate.value = true;
                      init();
                    },
                    icon: Icon(IconsaxPlusLinear.close_square, color: AppColors.grey),
                  ),
                ],
              ),
            ],
          ),
          MyDivider(),
          MyTab(
            tab: const ['همه', 'تسویه‌شده', 'تسویه‌نشده'],
            value: filterStatus,
            callback: (c) {
              filterStatus.value = c;
              init();
            },
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Flexible(
                child: BTN(
                  borderOnly: true,
                  color: darkMode.value ? AppColors.background : AppColors.backgroundDarkMode,
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
      title: 'فیلتر نمایش هزینه‌ها',
    );
  }

  init() async {
    costList = cost.values
        .where(
          (c) =>
              (allDate.isTrue ? true : (DateTime.parse(c.date!).isBefore(jEndDate.toDateTime()) && DateTime.parse(c.date!).isAfter(jStartDate.toDateTime()))) &&
              (filterStatus.value == 'همه'
                  ? true
                  : filterStatus.value == 'تسویه‌شده'
                  ? CostFX.unPaid(c) == 0
                  : CostFX.unPaid(c) > 0),
        )
        .toList();
    costList.sort((a, b) => b.date.compareTo(a.date));
    costList.sort((a, b) => b.id.compareTo(a.id));
    shippingCostList = invoice.values.where((element) => element.shipping!['cost']! > 0).toList();

    shippingCostList.sort((a, b) {
      final da = getStatus3Date(a);
      final db = getStatus3Date(b);

      if (da == null && db == null) return 0;
      if (da == null) return 1; // آیتم بدون status=3 بره آخر
      if (db == null) return -1;

      return db.compareTo(da);
    });
    change.toggle();
    return '';
  }

  static DateTime? getStatus3Date(item) {
    final List statuses = item.status ?? [];

    for (final s in statuses) {
      if (s['status'] == 3 && s['date'] != null && s['date'] != '') {
        return DateTime.tryParse(s['date']);
      }
    }
    return null; // اگر نداشت
  }
}
