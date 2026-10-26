import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/product/screen/components/catItem.dart';

import 'controllers/costCat.dart';

CostCatScreenController costCatScreenController =
    Get.put(CostCatScreenController());

class CostCatTab extends GetView {
  const CostCatTab({super.key});

  @override
  Widget build(BuildContext context) {
    costCatScreenController.init();
    return Expanded(
        child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
            padding: const EdgeInsets.only(right: 10),
            child: const Text(
              'لیست دسته‌بندی‌ها',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            )),
        const SizedBox(height: 45),
        // IconButton(
        //     onPressed: () {},
        //     icon: const RotatedBox(
        //         quarterTurns: 1, child: Icon(IconsaxPlusLinear.setting_5)))
      ]),
      Expanded(
          child: costCategory.isNotEmpty
              ? Obx(() => costCatScreenController.cat.isEmpty
                  ? EmptyList(
                      text: 'دسته‌بندی با این مشخصات موجود نیست!',
                      icon: IconsaxPlusLinear.box_search,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      controller: costCatScreenController.scl,
                      itemCount: costCatScreenController.cat.length,
                      itemBuilder: (context, index) {
                        return CategoryItem(
                          item: costCatScreenController.cat[index],
                          index: index,
                          type: 'cost',
                          callback: (v) {
                            costCatScreenController.init();
                          },
                        );
                        //return Container();
                      },
                    ))
              : EmptyList(
                  text: 'هیچ دسته‌بندی وجود ندارد!',
                  icon: IconsaxPlusLinear.box_search,
                ))
    ]));
  }
}
