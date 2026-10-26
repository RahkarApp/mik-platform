import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_pages/chatBase/addProduct/common/addGroupDetailsController.dart';

class ProductProperty {
  String name = '';
  final RxList<String> values = <String>[].obs;
  final TextEditingController valueInputController = TextEditingController();
  String? uid;
  RxList<Map> valuesWithId = <Map>[].obs;
  ProductProperty() {
    // Auto-generate variants when properties change
    debounce(
        values,
        (_) => Get.find<AddGroupDetailsController>().generateVariants(
            Get.find<AddGroupDetailsController>().products[
                Get.find<AddGroupDetailsController>().currentPage.value]),
        time: const Duration(milliseconds: 500));
  }
}
