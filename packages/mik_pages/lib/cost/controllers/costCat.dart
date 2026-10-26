import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:persian_number_utility/persian_number_utility.dart';


class CostCatScreenController extends GetxController {
  RxList<CostCategoryDB> cat = <CostCategoryDB>[].obs;
  RxString search = ''.obs;
  final scl = ScrollController();
  init() {
    if (search.value.length >= 2) {
      cat.value = costCategory.values
          .where((w) =>
              w.name!
                  .replaceAll(' ', '')
                  .toLowerCase()
                  .toEnglishDigit()
                  .contains(search.value
                      .replaceAll(' ', '')
                      .toLowerCase()
                      .toEnglishDigit()) ||
              w.id
                      .toString()
                      .toEnglishDigit()
                      .replaceAll(' ', '')
                      .toLowerCase() ==
                  search.value
                      .toEnglishDigit()
                      .replaceAll(' ', '')
                      .toLowerCase())
          .toList();
    } else if (search.value.length < 2) {
      cat.value = costCategory.values.toList().toList();
    }
    return '';
  }
}
