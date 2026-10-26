import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/cost/remote_screen.dart';
// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_components/elements/titledList.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/utils/fx/cost.dart';
import 'package:mik_pages/cost/cat.dart';
import 'package:mik_router/routing.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'controllers/cost.dart';

CostScreenController costScreenController = Get.put(CostScreenController());

class CostScreen extends GetView {
  const CostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (BusinessContext.forApp('mik') != null) {
      return const RemoteExpensesScreen(appId: 'mik');
    }
    return Main(
      initState: () async => await costScreenController.init(),
      header: Header.page(context, text: 'هزینه‌ها'),
      floatingActionButton: Obx(
        () => costScreenController.currentIndex.value == 0
            ? MyFAB(
                icon: IconsaxPlusLinear.add,
                text: 'هزینه جدید',
                onTap: () async {
                  await Get.toNamed(RoutesName.COSTADD);
                  costScreenController.filtered = false.obs;
                  costScreenController.jStartDate = Jalali.now().addDays(-30);
                  costScreenController.jEndDate = Jalali.now();
                  costScreenController.init();
                },
              )
            : costScreenController.currentIndex.value == 2
            ? MyFAB(
                icon: IconsaxPlusLinear.add,
                text: 'دسته‌بندی جدید',
                onTap: () async {
                  //  await Get.toNamed(RoutesName.COSTADD);
                  CostFX.addCat(
                    context,
                    callback: (d) {
                      costScreenController.init();
                    },
                  );
                },
              )
            : Container(),
      ),
      child: (d) => Column(
        children: [
          MyTabBar(
            tabs: const ['هزینه‌ها', 'ارسال محصولات', 'دسته‌بندی‌ها'],
            currentIndex: costScreenController.currentIndex.value,
            divider: false,
            index: (i) {
              costScreenController.currentIndex.value = i;
              costScreenController.costType.value = i == 0
                  ? 'هزینه‌ها'
                  : i == 1
                  ? 'ارسال محصولات'
                  : 'دسته‌بندی‌ها';
            },
          ),
          costScreenController.costType.value == 'هزینه‌ها'
              ? Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.only(right: 10),
                            child: const Text('لیست هزینه‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          Stack(
                            children: [
                              IconButton(
                                onPressed: () => costScreenController.filter(context),
                                icon: const RotatedBox(quarterTurns: 1, child: Icon(IconsaxPlusLinear.setting_5)),
                              ),
                              Obx(
                                () => costScreenController.filtered.isTrue
                                    ? Container(
                                        alignment: Alignment.topRight,
                                        padding: const EdgeInsets.only(top: 9, right: 7),
                                        child: CircleAvatar(backgroundColor: AppColors.primary, maxRadius: 5),
                                      )
                                    : Container(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Expanded(
                        child: costScreenController.change.isFalse || costScreenController.change.isTrue
                            ? costScreenController.costList.isNotEmpty
                                  ? TitledList(
                                      data: costScreenController.costList,
                                      type: TitledListType.cost,
                                      callback: (_) {
                                        costScreenController.init();
                                      },
                                    )
                                  : EmptyList(text: 'هزینه ای برای نمایش وجود ندارد.', icon: IconsaxPlusLinear.warning_2)
                            : Container(),
                      ),
                    ],
                  ),
                )
              : costScreenController.costType.value == 'ارسال محصولات'
              ? Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.only(right: 10),
                            child: const Text('لیست هزینه‌های ارسال محصولات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 45),
                          // IconButton(
                          //     onPressed: () {},
                          //     icon: const RotatedBox(
                          //         quarterTurns: 1,
                          //         child:
                          //             Icon(IconsaxPlusLinear.setting_5)))
                        ],
                      ),
                      Expanded(
                        child: Obx(
                          () => costScreenController.change.isFalse || costScreenController.change.isTrue
                              ? costScreenController.shippingCostList.isNotEmpty
                                    ? TitledList(data: costScreenController.shippingCostList, type: TitledListType.shippingCost, callback: (_) {})
                                    : EmptyList(text: 'هنوز هزینه ارسالی ثبت نکردید.', icon: IconsaxPlusLinear.truck_fast)
                              : Container(),
                        ),
                      ),
                    ],
                  ),
                )
              : CostCatTab(),
        ],
      ),
    );
  }
}
