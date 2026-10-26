// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/myTabbar.dart';

import 'package:mik_data/models/models.dart';
import 'package:mik_pages/customers/screen/detail/controller.dart';

CustomerDetailsController customerDetailsController = Get.put(
  CustomerDetailsController(),
);

class CustomerDetails extends StatefulWidget {
  PersonDB item;
  CustomerDetails(this.item, {super.key});

  @override
  State<CustomerDetails> createState() => _CustomerDetailsState();
}

class _CustomerDetailsState extends State<CustomerDetails> {
  @override
  void initState() {
    super.initState();
    customerDetailsController.item = widget.item;
  }

  @override
  Widget build(BuildContext context) {
    return Main(
      initState: () async => customerDetailsController.init(
        customerDetailsController.currentIndex.value,
      ),
      header: Header.page(context, text: customerDetailsController.item.name!),
      child: (d) => Column(
        children: [
          customerDetailsController.head(context),
          //const SizedBox(height: 10),
          Obx(
            () => MyTabBar(
              divider: false,
              tabs: const ['فاکتورها', 'ارتباطات', 'مالی', 'چک‌ها', 'گزارشات'],
              currentIndex: customerDetailsController.currentIndex.value,
              index: (v) {
                customerDetailsController.currentIndex.value = v;
              },
            ),
          ),
          Expanded(
            child: Obx(
              () => customerDetailsController.currentIndex.value == 0
                  ? customerDetailsController.factors()
                  : customerDetailsController.currentIndex.value == 1
                  ? customerDetailsController.connectionW()
                  : customerDetailsController.currentIndex.value == 2
                  ? customerDetailsController.financial()
                  : customerDetailsController.currentIndex.value == 3
                  ? customerDetailsController.chequew()
                  : customerDetailsController.report(),
            ),
          ),
        ],
      ),
    );
  }
}
