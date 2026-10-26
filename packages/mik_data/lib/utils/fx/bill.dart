// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_utils/public/price.dart';


import '../../models/models.dart';
import '../saveHelper.dart';
import '../variable.dart';

class BillFX {
  static canDelete(String toUID) {
    var b = bill.values.where((element) => element.toUID == toUID).toList();
    if (b.length <= 1) {
      return true;
    } else {
      return false;
    }
  }

  static find(String uid) {
    var b = bill.values.where((element) => element.uid == uid).toList();
    if (b.isNotEmpty) {
      return b[0];
    } else {
      return BillDB(uid: '', toUID: '', debtorUID: '', inserter: 0, creditorUID: '', meta: {});
    }
  }

  static int findIndex(String uid) {
    for (var i = 0; i < bill.length; i++) {
      if (bill.getAt(i)!.uid == uid) {
        return i;
      }
    }
    return 0;
  }

  static type(type) {
    switch (type) {
      case 'paid':
        return 'نقدی';
      case 'credit':
        return 'اقساط';
      case 'online':
        return 'آنلاین';
      case 'cheque':
        return 'چک';
      case 'deleted':
        return 'حذف شده';
      default:
    }
  }

  // static total(String uid) {
  //   return bill.values.where((element) => uid.contains(element.uid)).toList();
  // }

  static totalPaid(List<String> uids) {
    var bills = bill.values.where((element) => uids.contains(element.uid)).toList();
    num paid = 0;
    for (var element in bills) {
      paid += element.paid!;
    }
    return paid;
  }

  static add({
    required String jdate,
    required int price,
    required int personId,
    required String personUID,
    required allBill,
    required int totalPay,
    required id,
    required uid,
    required int indexBill,
    required bool isEdit,
  }) async {
    var date = DateConvertor.jalaliToGrigori(jdate);
    if (financialPeriod.length > 0 &&
        (DateTime.parse(date).isBefore(DateTime.parse(financialPeriod.getAt(financialPeriod.length - 1)!.endDate!)) ||
            DateTime.parse(date).compareTo(DateTime.parse(financialPeriod.getAt(financialPeriod.length - 1)!.endDate!)) == 0)) {
      return Alert.error('امکان ثبت صورتحساب در دوره قبل وجود ندارد.');
    } else if (price == 0 || personId == 0 || jdate.isEmpty) {
      return Alert.error('پرداخت کننده، مبلغ و تاریخ باید وارد شوند.');
    } else if (allBill != null && allBill![0].to != 'ff' && allBill![0].total! - totalPay < price) {
      Alert.error('مبلغ پرداختی نمیتواند از ${Price.showWithCurrency((allBill![0].total! - totalPay))} بیشتر باشد.');
    } else {
      BillDB? b;
      if (id != null) b = bill.getAt(indexBill)!;
      BillDB billItem = BillDB(
        id:
            id ??
            (bill.length == 0
                ? 1
                : (ID.endId(bill)).toString().startsWith('10000')
                ? int.parse(ID.endId(bill).toString().substring(4)) + 1
                : ID.newId(bill)),
        uid: uid ?? ID.uidNew(),
        debtor: id == null ? personId : b!.debtor,
        creditor: id == null ? 0 : b!.creditor,
        debtorUID: id == null ? personUID : b!.debtorUID,
        creditorUID: id == null ? '' : b!.creditorUID,
        total: id == null
            ? price
            : b!.to == 'ff'
            ? price
            : b.total,
        paid: price,
        unPaid: 0,
        to: id == null ? 'ff' : b!.to,
        toUID: id == null ? 'ff' : b!.toUID,
        date: date,
        deadLine: date,
        type: id == null ? '' : b!.type,
        inserter: 0,
        backup: id == null ? 'new' : 'edit',
        meta: {},
      );
      // int index = -1;
      // if (isEdit) {
      //   for (var i = 0; i < bill.length; i++) {
      //     if (b.uid == uid!) index = i;
      //   }
      // }
      !isEdit ? await SaveHelper.save(billItem) : await SaveHelper.save(billItem, index: indexBill);
      // isEdit.isFalse
      //     ? await bill.add(billItem)
      //     : await bill.putAt(index, billItem);
      // isEdit.isFalse
      //     ? API.addBill(billItem.toJson())
      //     : API.editBill(billItem.toJson());
      Alert.success(!isEdit ? 'صورتحساب با موفقیت ایجاد شد.' : 'صورتحساب با موفقیت ویرایش شد.');
      return 'ok';
    }
  }

  static delete(String uid) async {
    BillDB b = bill.values.where((element) => element.uid == uid).toList()[0];
    if (b.toUID!.startsWith('F-')) {
      for (var i = 0; i < invoice.length; i++) {
        InvoiceDB f = invoice.getAt(i)!;
        if ('F-${f.uid}' == b.toUID!) {
          f.billUID!.remove(b.uid);
          await SaveHelper.save(f, index: i);
        }
      }
    } else if (b.toUID!.startsWith('C-')) {
      for (var i = 0; i < cost.length; i++) {
        CostDB c = cost.getAt(i)!;
        if ('C-${c.uid}' == b.toUID!) {
          c.billUID!.remove(b.uid);
          await SaveHelper.save(c, index: i);
        }
      }
    }
    for (var i = 0; i < bill.length; i++) {
      if (bill.getAt(i)!.uid == uid) {
        await SaveHelper.delete(bill.getAt(i)!, i);
        Get.back();
        Get.back();
        Alert.success('حذف با موفقیت انجام شد.');
        break;
      }
    }
  }

  static addNewBillForItem(
    context,
    List billUID,
    callback,
    paid,

    ///debt,creadit
    mode,
  ) {
    var item = bill.values.where((element) => element.uid == billUID[0]).toList()[0];
    final paidCtl = TextEditingController();
    final paidF = FocusNode();
    paidF.requestFocus();
    MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        children: [
          PriceInput(name: 'مبلغ', controller: paidCtl, focusNode: paidF, desc: '   مجموع مانده: ${Price.showWithCurrency((item.total! - paid))}'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: BTN(
                  name: 'افزودن',
                  type: BTNType.ok,
                  onTap: () async {
                    if (paidCtl.text.isEmpty) {
                      Get.back();
                      return;
                    } else if (item.total! - paid - Price.toInt(paidCtl.text) < 0) {
                      return Alert.error(mode == 'debt' ? 'مبلغ پرداختی نمیتواند از مانده بیشتر باشد.' : 'مبلغ دریافتی نمیتواند از مانده بیشتر باشد.');
                    } else {}
                    await addBill(item, double.parse('${Price.toInt(paidCtl.text)}.0'), callback, mode);
                  },
                ),
              ),
              Flexible(
                child: BTN(
                  name: 'انصراف',
                  type: BTNType.cancel,
                  onTap: () {
                    Get.back();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      title: mode == 'پرداخت' ? 'ثبت پرداخت جدید برای ${toFind(item.toUID!, mode)}' : 'ثبت دریافت وجه جدید برای ${toFind(item.toUID!, mode)}',
    );
  }

  static addBill(BillDB item, double price, callback, mode) async {
    // _load = false.obs;
    BillDB it = BillDB(
      id: (ID.endId(bill)).toString().startsWith('10000') ? int.parse((ID.endId(bill)).toString().substring(4)) + 1 : ID.newId(bill),
      uid: ID.uidNew(),
      debtor: item.debtor,
      creditor: item.creditor,
      debtorUID: item.debtorUID,
      creditorUID: item.creditorUID,
      total: item.total,
      paid: price,
      unPaid: item.total! - price - item.paid!,
      to: item.to,
      toUID: item.toUID,
      date: DateTime.now().toIso8601String(),
      deadLine: item.deadLine,
      inserter: 0,
      type: item.type,
      meta: {},
    );
    await SaveHelper.save(it);
    // await bill.add(it);
    // API.addBill(it.toJson());
    CostDB? thisCost;
    if ((item.to.toString().startsWith('f') || item.toUID.toString().startsWith('F-')) && item.to != 'f0') {
      // int fID = int.parse(item.to.toString().replaceAll('f', ''));
      InvoiceDB? thisInvoice;

      int index = -1;
      for (var i = 0; i < invoice.length; i++) {
        var element = invoice.getAt(i);
        if (element!.uid == item.toUID.toString().replaceAll('F-', '')) {
          thisInvoice = element;
          index = i;
        }
      }
      // thisFactor!.billID!.add(it.id);
      thisInvoice!.billUID!.add(it.uid!);
      //await SaveHelper.save(thisFactor, index: index);

      var invoiceData = {
        'invoice': thisInvoice.toJson(),
        'bill': [it.toJson()],
        'cheque': [],
        'type': 'edit',
      };
      await SaveHelper.addInvoice(invoiceData);

      // await factor.putAt(index, thisFactor);
      // API.editFactor(thisFactor.toJson());
    } else if (item.to.toString().startsWith('c') || item.toUID.toString().startsWith('C-')) {
      String fID = item.toUID.toString().replaceAll('C-', '');

      int index = -1;
      for (var i = 0; i < cost.length; i++) {
        var element = cost.getAt(i);
        if (element!.uid == fID) {
          thisCost = element;
          index = i;
        }
      }
      // thisCost!.billID!.add(it.id);
      thisCost!.billUID!.add(it.uid);
      await SaveHelper.save(thisCost, index: index);
      // await cost.putAt(index, thisCost);
      // API.editCost(thisCost.toJson());
    }
    callback('change');
    // Get.back();
    Get.back();
    Alert.success(
      mode == 'debt'
          ? item.to!.startsWith('f') || item.toUID!.startsWith('F-')
                ? 'پرداخت با موفقیت برای فاکتور ${(item.to ?? item.toUID)!.substring(1)} ثبت شد.'
                : 'پرداخت با موفقیت برای هزینه ${thisCost!.id} ثبت شد.'
          : 'دریافت با موفقیت برای فاکتور ${(item.to ?? item.toUID)!.substring(1)} ثبت شد.',
    );
  }

  static toFind(String toUID, mode) {
    if (toUID.startsWith('1') && mode == 'پرداخت') return 'بدهی اول دوره';
    if (toUID.startsWith('1') && mode != 'پرداخت') return 'طلب اول دوره';
    if (toUID.startsWith('F-')) return 'فاکتور';
    if (toUID.startsWith('C-')) return 'هزینه';
  }
}
