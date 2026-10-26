import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/titledList.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_pages/persons/supplier/controller.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';

import '../components/details.dart';

PersonSupplierScreenController personSupplierScreenController = Get.put(
  PersonSupplierScreenController(),
);

class SupplierDetailsScreen extends GetView {
  PersonDB item;
  SupplierDetailsScreen(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () =>
          personSupplierScreenController.change.isFalse ||
              personSupplierScreenController.change.isTrue
          ? Main(
              initState: () async =>
                  await personSupplierScreenController.init(item),
              header: Header.page(context, text: item.name!),
              child: (d) => Column(
                children: [
                  const SizedBox(height: 10),
                  PersonDetails.header(
                    context,
                    item,
                    callback: (v) {
                      if (v.runtimeType.toString() == 'PersonDB') item = v;
                      personSupplierScreenController.init(item);
                      personSupplierScreenController.change.toggle();
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('مجموع خرید: '),
                            Text(
                              Price.showWithCurrency(
                                personSupplierScreenController.total.value +
                                    personSupplierScreenController
                                        .discount
                                        .value,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('مجموع تخفیف دریافتی: '),
                            Text(
                              Price.showWithCurrency(
                                personSupplierScreenController.discount.value,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('خالص خرید: '),
                            Text(
                              Price.showWithCurrency(
                                personSupplierScreenController.total.value,
                              ),
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
                        color: darkMode.value
                            ? Colors.grey.shade900
                            : Colors.white,
                        borderRadius: BorderRadius.only(
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
                              'فاکتورها: ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TitledList(
                              data: personSupplierScreenController.inv,
                              type: TitledListType.factor,
                              callback: (v) {
                                personSupplierScreenController.init(item);
                              },
                            ),
                          ),
                          // Expanded(
                          //     child: ListView.builder(
                          //   itemCount: fct.length,
                          //   padding: EdgeInsets.zero,
                          //   itemBuilder: (context, index) {
                          //     return InvoiceItem(
                          //         item: fct[index],
                          //         callback: (v) {
                          //           init();
                          //         },
                          //         end: index + 1 == fct.length);
                          //   },
                          // ))
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Container(),
    );
  }
}
