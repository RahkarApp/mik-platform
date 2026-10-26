import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/titledList.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/permissionfx.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/persons/components/details.dart';
import 'package:mik_utils/public/analytics.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';

class ServicerDetailsScreen extends GetView {
  PersonDB item;
  ServicerDetailsScreen(this.item, {super.key});
  RxList<CostDB> cl = <CostDB>[].obs;
  RxInt total = 0.obs;
  @override
  Widget build(BuildContext context) {
    return Main(
      initState: () async => init(),
      header: Header.page(context, text: item.name!),
      child: (d) => Column(
        children: [
          const SizedBox(height: 10),
          PersonDetails.header(
            context,
            item,
            callback: (v) {
              init();
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مجموع هزینه: '),
                    Text(
                      Price.showWithCurrency(total.value),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: Get.width,
              decoration: BoxDecoration(
                color: darkMode.value ? Colors.grey.shade900 : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(top: 5, right: 10),
                    child: const Text(
                      'هزینه‌ها: ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TitledList(
                      data: cl,
                      type: TitledListType.cost,
                      callback: (v) {
                        init();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  init() {
    Analytics.pageView();

    total.value = 0;
    cl.value = cost.values.where((c) => c.personUID == item.uid).toList();
    for (var e in cl) {
      total.value += e.price!.toInt();
    }

    cl.value = cl.where((f) => PermissionFx.isShowCostItem(f)).toList();
    return '';
  }
}
