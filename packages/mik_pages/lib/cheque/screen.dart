import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/cheque/remote_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_components/elements/titledList.dart';

import 'package:mik_consts/colors.dart';
import 'package:mik_pages/cheque/components/form.dart';

import 'controller.dart';

//  const [
//               'همه',
//               'پاس شده',
//               'سررسید شده',
//               'سررسید نشده',
//               // 'پاس نشده'
//             ],

ChequeScreenController chequeScreenController = Get.put(ChequeScreenController());

class ChequeScreen extends GetView {
  const ChequeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (BusinessContext.forApp('mik') != null) {
      return const RemoteChequeScreen(appId: 'mik');
    }
    return Main(
      initState: () async => await chequeScreenController.init(),
      header: Header.page(context, text: 'چک‌ها'),
      floatingActionButton: MyFAB(
        icon: IconsaxPlusLinear.add,
        text: 'چک جدید',
        onTap: () {
          MyBottomSheet.view(
            context,
            child: (scrollController) => ChequeAddForm(controller: scrollController, callback: (v) => chequeScreenController.init()),
            title: 'ثبت چک',
          );
        },
      ),
      child: (d) => Column(
        children: [
          MyTabBar(
            tabs: const ['همه', 'دریافتی', 'پرداختی'],
            currentIndex: chequeScreenController.currentIndex.value,
            divider: false,
            index: (i) {
              chequeScreenController.currentIndex.value = i;
              chequeScreenController.mode.value = i == 0
                  ? 'همه'
                  : i == 1
                  ? 'دریافتی'
                  : 'پرداختی';
              chequeScreenController.submodeIndex.value = 1;
              chequeScreenController.submode.value = 'سررسید';
              chequeScreenController.init();
            },
          ),
          MyTabBar(
            tabs: const ['همه', 'سررسید', 'پاس‌شده', 'درانتظار', 'پاس‌نشده'],
            currentIndex: chequeScreenController.submodeIndex.value,
            color: AppColors.primaryLite,
            divider: false,
            index: (i) {
              chequeScreenController.submodeIndex.value = i;
              chequeScreenController.submode.value = i == 0
                  ? 'همه'
                  : i == 1
                  ? 'سررسید'
                  : i == 2
                  ? 'پاس‌شده'
                  : i == 3
                  ? 'درانتظار'
                  : 'پاس‌نشده';
              chequeScreenController.init();
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  chequeScreenController.mode.value == 'همه' ? 'لیست همه چک‌ها' : 'لیست چک‌ها ${chequeScreenController.mode.value}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 45),
              // IconButton(
              //     onPressed: () {},
              //     icon: const RotatedBox(
              //         quarterTurns: 1, child: Icon(IconsaxPlusLinear.setting_5)))
            ],
          ),
          Expanded(
            child: Obx(
              () => chequeScreenController.chequeList.isNotEmpty
                  ? TitledList(data: chequeScreenController.chequeList, type: TitledListType.cheque, callback: (_) => {chequeScreenController.init()})
                  : EmptyList(icon: IconsaxPlusLinear.money_4, text: chequeScreenController.submode.value == 'همه' ? 'هیچ چکی ثبت نشده!' : 'چک ${chequeScreenController.submode.value} ندارید!'),
            ),
          ),
        ],
      ),
    );
  }
}
