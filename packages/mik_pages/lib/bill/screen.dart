import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/bill/remote_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_components/elements/titledList.dart';

import 'package:mik_pages/bill/controller.dart';

BillScreenController billScreenController = Get.put(BillScreenController());

class BillScreen extends GetView {
  BillScreen({this.isCredit = false, super.key});

  bool isCredit;
  @override
  Widget build(BuildContext context) {
    if (BusinessContext.forApp('mik') != null) {
      return const RemoteBillScreen(appId: 'mik');
    }
    return Main(
      initState: () async => billScreenController.init(),
      header: Header.page(context, isBack: false, text: 'صورت‌حساب‌ها'),
      child: (d) => Column(
        children: [
          Obx(
            () => MyTabBar(
              tabs: const ['دریافت', 'پرداخت'],
              currentIndex: billScreenController.currentIndex.value,
              divider: false,
              index: (i) {
                billScreenController.currentIndex.value = i;
                billScreenController.mode.value = i == 0 ? 'دریافت' : 'پرداخت';

                billScreenController.init();
              },
            ),
          ),
          Obx(
            () =>
                billScreenController.change.isFalse ||
                    billScreenController.change.isTrue
                ? Expanded(
                    child: billScreenController.billItem.isEmpty
                        ? EmptyList(
                            icon: IconsaxPlusLinear.document_text,
                            text:
                                'هیچ صورت حساب ${billScreenController.mode.value}ی وجود ندارد!',
                          )
                        : TitledList(
                            data: billScreenController.billItem,
                            type: TitledListType.bill,
                            billMode: billScreenController.mode.value,
                            callback: (_) {
                              billScreenController.init();
                            },
                          ),
                  )
                : Container(),
          ),
        ],
      ),
    );
  }
}
