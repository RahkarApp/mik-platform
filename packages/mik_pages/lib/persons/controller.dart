import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/variable.dart';

import 'package:persian_number_utility/persian_number_utility.dart';

class PersonScreenController extends GetxController {
  RxList<PersonDB> prs = <PersonDB>[].obs;
  String search = '';
  RxString name = 'افراد'.obs;
  RxString addName = ''.obs;
  RxBool change = false.obs;

  init(type) async {
    prs.value = [];
    switch (type) {
      case 'partner':
        name.value = 'شرکا';
        addName.value = 'شریک جدید';
        prs.value = person.values
            .where((p) => p.isPartner! && con(p.name!, p.mobile!))
            .toList();
        break;
      case 'supplier':
        name.value = 'تامین‌کنندگان';
        addName.value = 'تامین‌کننده جدید';
        prs.value = person.values
            .where((p) => p.isSupplier! && con(p.name!, p.mobile ?? ''))
            .toList();
        break;
      case 'servicer':
        name.value = 'سرویس‌دهندگان';
        addName.value = 'سرویس‌دهنده جدید';
        prs.value = person.values
            .where((p) => p.isService! && con(p.name!, p.mobile ?? ''))
            .toList();
        break;
      case 'marketer':
        name.value = 'پرسنل';
        addName.value = 'پرسنل جدید';
        prs.value = person.values
            .where((p) => p.isMarketer! && con(p.name!, p.mobile ?? ''))
            .toList();
        break;
      case 'customer':
        name.value = 'مشتریان';
        addName.value = 'مشتری جدید';
        prs.value = person.values
            .where((p) => p.isCustomer! && con(p.name!, p.mobile ?? ''))
            .toList();
        break;

      default:
    }
    return '';
  }

  bool con(String name, String mobile) {
    if (search.isEmpty) return true;
    if (name.isEmpty) return true;
    return name.toLowerCase().toEnglishDigit().contains(
          search.toLowerCase().toEnglishDigit(),
        ) ||
        mobile.toLowerCase().toEnglishDigit().contains(
          search.toLowerCase().toEnglishDigit(),
        );
  }
}
