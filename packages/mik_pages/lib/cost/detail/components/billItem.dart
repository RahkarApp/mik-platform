// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_utils/public/price.dart';

import 'package:persian_number_utility/persian_number_utility.dart';

class CostBillItem extends GetView {
  BillDB bill;
  int index;
  var callback;
  CostBillItem(
      {super.key,
      required this.bill,
      required this.index,
      required this.callback});
  bool firstPaid = true;
  @override
  Widget build(BuildContext context) {
    if (index == 0 && bill.paid == 0) {
      firstPaid = false;
    }
    return bill.paid! > 0
        ? Column(
            children: [
              InkWell(
                onLongPress: () async {
                  if (bill.type == 'credit' || bill.type == 'paid') {
                    await Get.toNamed(RoutesName.BILLADD, arguments: {
                      'billId': bill.id,
                      'billUId': bill.uid,
                      'mode': 'debt'
                    });
                    callback('v');
                  } else {
                    Alert.info('این پرداخت قابل ویرایش نیست.');
                  }
                },
                child: Container(
                    padding: const EdgeInsets.only(right: 20, left: 10),
                    height: 40,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                              flex: 3,
                              fit: FlexFit.tight,
                              child: Row(children: [
                                SizedBox(
                                    width: 30,
                                    child: Text(
                                      firstPaid
                                          ? (index + 1).toString()
                                          : index.toString(),
                                      style: const TextStyle(fontSize: 16),
                                    )),
                                Text(Price.showWithCurrency(bill.paid!),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                    textAlign: TextAlign.start)
                              ])),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(bill.date.toString().toPersianDate()),
                          ),
                          Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                index == 0 &&
                                        bill.type == 'credit' &&
                                        bill.paid! > 0
                                    ? 'نقدی'
                                    : bill.type == 'credit'
                                        ? 'اقساطی'
                                        : bill.type == 'cheque'
                                            ? 'چک'
                                            : 'نقد',
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.end,
                              ))
                        ])),
              ),
              EndLine(rightPadding: 40)
            ],
          )
        : Container();
  }
}
