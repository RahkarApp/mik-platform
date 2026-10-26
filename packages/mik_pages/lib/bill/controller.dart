import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_data/utils/fx/permissionfx.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/variable.dart';

class BillScreenController extends GetxController {
  var billItem = [
        {
          'id': 0,
          'uid': '',
          'to': 'all[0].to',
          'person': 1,
          'personUID': '',
          'date': '',
          'total': 0,
          'paid': 0,
          'debt': 0,
          'deadLine': '',
          'mode': 'debt',
          'checkout': false,
          'billItem': [],
        },
      ],
      billItemDetails = [];
  RxString mode = 'دریافت'.obs;
  RxBool change = false.obs;
  RxBool anim = false.obs;
  RxInt currentIndex = 0.obs;
  num totalDebt = 0, totalCredit = 0;
  init() async {
    await Future.delayed(Duration(seconds: 1));
    billItem = [];
    billItemDetails = [];
    var allBill = [];
    for (var fc in invoice.values) {
      var items = bill.values
          .where((element) => fc.billUID!.contains(element.uid))
          .toList();
      if (items.isNotEmpty) {
        allBill.add(items);
      }
    }
    var checkBillF0 = [];
    var checkBillF0D = [];
    for (var element in bill.values) {
      // print('element: ${element.toJson()}');
      if (element.toUID == '1' &&
          (element.debtorUID == '' || element.debtorUID == '-')) {
        checkBillF0.add(element);
      } else if (element.toUID == '1' &&
          (element.creditorUID == '' || element.creditorUID == '-')) {
        checkBillF0D.add(element);
      }
    }
    List<String> pList = [];
    for (BillDB element in checkBillF0) {
      if (!pList.contains(element.creditorUID!)) {
        pList.add(element.creditorUID!);
      }
    }
    for (String p in pList) {
      allBill.add(
        checkBillF0.where((element) => element.creditorUID == p).toList(),
      );
    }
    pList = [];
    for (var element in checkBillF0D) {
      if (!pList.contains(element.debtorUID!)) {
        pList.add(element.debtorUID);
      }
    }
    for (var p in pList) {
      allBill.add(
        checkBillF0D.where((element) => element.debtorUID == p).toList(),
      );
    }

    for (var fc in cost.values) {
      allBill.add(
        bill.values
            .where((element) => fc.billUID!.contains(element.uid))
            .toList(),
      );
    }

    billItemDetails = allBill;
    //for (var all in allBill) {
    for (var i = 0; i < allBill.length; i++) {
      var all = allBill[i];

      var per = 0, mod = 'پرداخت', checkout = false, perUID = '';
      num paid = 0, unPaid = 0;
      for (var i = 0; i < all.length; i++) {
        if (all[i].toUID == '1') {
          print(all[i].toJson());
        }
        paid = paid + all[i].paid;
        unPaid = all[i].total - paid;
      }

      if (all.isNotEmpty) {
        if ((all[0].debtorUID == '' || all[0].debtorUID == '-') &&
            (all[0].creditorUID != '-' || all[0].creditorUID != '')) {
          mod = 'پرداخت';
        } else {
          //per = all[0].debtor;
          perUID = all[0].debtorUID;
        }

        if ((all[0].debtorUID != '' || all[0].debtorUID != '-') &&
            (all[0].creditorUID == '-' || all[0].creditorUID == '')) {
          mod = 'دریافت';
        } else {
          //  per = all[0].creditor;
          perUID = all[0].creditorUID;
        }

        if (all[0].total <= paid) checkout = true;

        if (mod == mode.value && all[0].type != 'deleted') {
          billItem.add({
            'id': all[0].id,
            'uid': all[0].uid,
            'to': all[0].to ?? all[0].toUID,
            'toUID': all[0].toUID,
            'person': per,
            'personUID': perUID,
            'date': all[0].date ?? DateTime.now().toIso8601String(),
            'total': all[0].total,
            'paid': paid,
            'debt': unPaid,
            'deadLine': all[0].deadLine ?? "-",
            'mode': mod,
            'checkout': checkout,
            'type': all[0].type,
            'inserter': all[0].inserter,
            'billItem': all,
          });
          if (all[0].toUID == '1') {}
        }

        if (mod == 'پرداخت') {
          totalDebt = totalDebt + (all[0].total - paid);
        } else {
          totalCredit = totalCredit + (all[0].total - paid);
        }
      }
    }
    var billItemNotCheckout = billItem
        .where(
          (element) =>
              element['checkout'] == false && element['type'] != 'smart',
        ) //smart bill not Checkout notShow
        .toList();

    var billItemCheckout = billItem
        .where((element) => element['checkout'] == true)
        .toList();
    billItemNotCheckout.sort(
      (b, a) =>
          DateTime.parse(
            a['deadLine'] == '-' || a['deadLine'] == '' || b['deadLine'] == null
                ? a['date'].toString()
                : a['deadLine'].toString(),
          ).compareTo(
            DateTime.parse(
              (b['deadLine'] == '-' ||
                      b['deadLine'] == '' ||
                      b['deadLine'] == null
                  ? b['date'].toString()
                  : b['deadLine'].toString()),
            ),
          ),
    );

    billItemCheckout.sort(
      (a, b) =>
          DateTime.parse(b['date'].toString())
              .compareTo(DateTime.parse((a['date'].toString()))),
    );
    billItem = [];
    billItem.addAll(billItemNotCheckout);
    billItem.addAll(billItemCheckout);
    billItem = billItem.where((b) => PermissionFx.isShowBillItem(b)).toList();

    change.toggle();
    return '';
  }
}
