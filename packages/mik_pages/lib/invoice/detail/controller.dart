// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/variable.dart';

class InvoiceDetailsScreenController extends GetxController {
  var type;
  var paid;
  RxList<BillDB> bills = <BillDB>[].obs;
  RxList<ChequeDB> chequeList = <ChequeDB>[].obs;
  RxBool change = false.obs;
  late InvoiceDB item;
  var scrollCtl = ScrollController();
  init({InvoiceDB? itemFactor}) async {
    // data = null;
    if (itemFactor != null && item!.uid == itemFactor.uid) {
      item = itemFactor;
    }
    // if (item != null) {
    bills.value = bill.values
        .where((element) => (item!.billUID!.contains(element.uid)))
        .toList();
    // }
    chequeList.value = cheque.values
        .where(
          (element) => element.toUID == ''
              ? element.to == 'f${item!.id}'
              : element.toUID == 'F-${item!.uid}',
        )
        .toList();

    chequeList.sort(
      (a, b) =>
          DateTime.parse(a.dueDate!).compareTo(DateTime.parse(b.dueDate!)),
    );

    paid = 0.0;
    for (var i = 0; i < bills.length; i++) {
      paid = paid + bills[i].paid!;
    }

    if (type != null && type == 'bill') {
      try {
        Future.delayed(const Duration(milliseconds: 200), () {
          scrollCtl.animateTo(
            scrollCtl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.ease,
          );
        });
      } catch (e) {}
    }

    change.toggle();
    return item;
  }
}
