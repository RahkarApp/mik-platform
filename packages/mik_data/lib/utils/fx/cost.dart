// ignore_for_file: collection_methods_unrelated_type, unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../models/models.dart';
import '../saveHelper.dart';
import '../variable.dart';

class CostFX {
  static unPaid(CostDB c) {
    var b = bill.values.where((element) => c.billUID!.contains(element.uid)).toList();
    int tp = 0;

    for (var i = 0; i < b.length; i++) {
      tp = tp + b[i].paid!.toInt();
    }
    if (b.isNotEmpty) {
      return b[0].total!.toInt() - tp;
    } else {
      return c.price;
    }
  }

  static cat(String uid) {
    try {
      return uid == '' ? 'کسب‌وکار' : costCategory.values.where((element) => element.uid == uid).toList()[0].name;
    } catch (e) {
      return '';
    }
  }

  static inCat(String uid) {
    return cost.values.where((e) => e.categoryUID == uid).toList().length;
  }

  static del(context, item, callback) async {
    Confirm.con(
      context,
      onTapConfirm: () async {
        for (var i = 0; i < cost.length; i++) {
          CostDB cc = cost.getAt(i)!;
          if (cc.uid == item.uid) {
            var res = await SaveHelper.delete(cc, i);
            if (res == '200') {
              for (var b = bill.length - 1; b >= 0; b--) {
                var element = bill.getAt(b)!;
                if (element.toUID == '' ? element.to == 'c${cc.id}' : element.toUID == 'C-${cc.uid}') {
                  await bill.deleteAt(b);
                }
              }
              Get.back();
              Alert.success('حذف هزینه با موفقیت انجام شد');
              callback('change');
            }
            break;
          }
        }
      },
      confirmText: 'تایید و حذف',
      type: ConfirmType.DELETE,
    );
  }

  // static toFind(to) {
  //   return to
  //       .toString()
  //       .replaceAll('f0', 'اول دوره')
  //       .replaceAll('ff', 'دریافتی بدون فاکتور')
  //       .replaceAll('c0', 'اول دوره')
  //       .replaceAll('f', 'فاکتور ')
  //       .replaceAll('c', 'هزینه ');
  // }

  static add({
    required item,
    required allBill,
    required String name,
    required String jdate,
    required String catUID,
    required String price,
    required String person,
    required int personID,
    required String personUID,
    required String paid,
    required bool cash,
    required bool isEdit,
    required int notPaid,
    required int otherPay,
    required String factorUID,
    required String deadLine,
    required String description,
  }) async {
    if (jdate.isEmpty) {
      return Alert.error('تاریخ را انتخاب کنید.');
    } else if (jdate.isNotEmpty) {
      var date = DateConvertor.jalaliToGrigori(jdate);
      if (financialPeriod.length > 0 &&
          (DateTime.parse(date).isBefore(DateTime.parse(financialPeriod.getAt(financialPeriod.length - 1)!.endDate!)) ||
              DateTime.parse(date).compareTo(DateTime.parse(financialPeriod.getAt(financialPeriod.length - 1)!.endDate!)) == 0)) {
        return Alert.error('امکان ثبت هزینه در دوره قبل وجود ندارد.');
      } else if (name.isEmpty || catUID == '' || price.isEmpty || person.isEmpty) {
        return Alert.error('عنوان هزینه، دسته‌بندی، قیمت و ارتباط با فرد باید وارد شوند.');
      } else if (notPaid - otherPay < 0) {
        return Alert.error('مبلغ پرداخت شده نمیتواند از مبلغ کل بیشتر باشد.');
      } else if (factorUID.isNotEmpty && factorUID != '-' && invoice.values.where((element) => element.uid == factorUID.substring(2)).toList().isEmpty) {
        return Alert.error('فاکتوری با شماره وارد شده یافت نشد.\nلطفا شماره فاکتور را مجددا بررسی نمایید.');
      } else {
        var dt = deadLine.split('/');

        var deadLineDate = Jalali(int.parse(dt[0].toEnglishDigit()), int.parse(dt[1].toEnglishDigit()), int.parse(dt[2].toEnglishDigit())).toGregorian().toDateTime().toIso8601String();
        String costUid = !isEdit ? ID.uidNew() : item.uid;
        int costid = !isEdit ? ID.newId(cost) : item.id;
        BillDB billItem = BillDB(
          id: allBill == null
              ? bill.length == 0
                    ? 1
                    : (ID.endId(bill)).toString().startsWith('10000')
                    ? int.parse((ID.endId(bill)).toString().substring(4)) + 1
                    : ID.newId(bill)
              : allBill[0].id,
          uid: allBill == null ? ID.uidNew() : allBill[0].uid,
          debtor: 0,
          creditor: personID,
          debtorUID: '',
          creditorUID: personUID,
          total: Price.toInt(price),
          paid: cash
              ? Price.toInt(price)
              : paid.isNotEmpty
              ? Price.toInt(paid)
              : 0,
          unPaid: cash
              ? 0
              : paid.isNotEmpty
              ? (Price.toInt(price) - Price.toInt(paid)).toInt()
              : Price.toInt(price),
          to: 'c$costid',
          toUID: 'C-$costUid',
          date: date,
          deadLine: !cash ? deadLineDate : date,
          type: cash ? 'paid' : 'credit',
          inserter: 0,
          backup: allBill == null ? 'new' : 'edit',
          meta: {},
        );
        // var billIDItem = [billItem.id];
        var billUIDItem = [billItem.uid];
        if (item != null) {
          List<String> oldBillUID = List.from(item.billUID);
          oldBillUID.remove(billUIDItem);
          if (oldBillUID.isNotEmpty) billUIDItem.addAll(oldBillUID);
        }
        CostDB cst = CostDB(
          id: costid,
          uid: costUid,
          name: name,
          billID: [],
          billUID: billUIDItem,
          categoryID: 0,
          categoryUID: catUID,
          price: Price.toInt(price),
          factorID: 0,
          factorUID: factorUID,
          personUID: personUID,
          personID: 0,
          description: !isEdit ? description : '$description ویرایش در ${DateTime.now().toIso8601String().toPersianDate()}',
          date: date,
          inserter: 0,
          backup: !isEdit ? 'new' : 'edit',
        );
        int index = -1, indexd = -1;
        if (isEdit) {
          for (var i = 0; i < cost.length; i++) {
            if (cost.getAt(i)!.uid == item.uid) index = i;
          }
          for (var i = 0; i < bill.length; i++) {
            if (bill.getAt(i)!.uid == item.billUID[0]) indexd = i;
          }
        }
        !isEdit ? await SaveHelper.save(cst) : await SaveHelper.save(cst, index: index);
        // isEdit.isFalse ? await cost.add(cst) : await cost.putAt(index, cst);
        // isEdit.isFalse ? API.addCost(cst.toJson()) :  API.editCost(cst.toJson());
        !isEdit ? await SaveHelper.save(billItem) : await SaveHelper.save(billItem, index: indexd);
        // isEdit.isFalse
        //     ? await bill.add(billItem)
        //     : await bill.putAt(indexd, billItem);
        // isEdit.isFalse
        //     ? API.addBill(billItem.toJson())
        //     : API.editBill(billItem.toJson());
        Alert.success('هزینه با موفقیت ثبت شد.');
        return cst;
      }
    }
  }

  static addCat(context, {int? index, required callback}) {
    CostCategoryDB? cat;
    int? idItem;
    String? uidItem;
    if (index != null && index > -1) {
      cat = costCategory.getAt(index)!;
      idItem = cat.id;
      uidItem = cat.uid;
    }
    final formKey = GlobalKey<FormState>();
    final nameCtl = TextEditingController(text: cat != null ? cat.name : '');
    final nameF = FocusNode();
    final descCtl = TextEditingController(text: cat != null ? cat.description : '');
    nameF.requestFocus();
    MyBottomSheet.view(
      context,
      child: (scrollController) => Obx(
        () => Form(
          key: formKey,
          child: Column(
            children: [
              Input(name: 'نام دسته‌بندی', focusNode: nameF, fillColor: darkMode.isFalse ? Colors.grey.shade300 : null, require: true, controller: nameCtl),
              Input(name: 'توضیحات', fillColor: darkMode.isFalse ? Colors.grey.shade300 : null, minLines: 2, maxLines: 2, controller: descCtl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: BTN(
                      name: cat == null ? 'افزودن' : 'ویرایش',
                      type: BTNType.ok,
                      onTap: () async {
                        // SystemChannels.textInput.invokeMethod('TextInput.hide');
                        if (nameCtl.text.isEmpty) {
                          Alert.error('نام دسته‌بندی را وارد کنید.');
                        } else {
                          var item = CostCategoryDB(
                            id: idItem ?? (ID.newId(costCategory)),
                            uid: uidItem ?? (ID.uidNew()),
                            name: nameCtl.text,
                            description: descCtl.text,
                            inserter: 0,
                            backup: idItem == null ? 'new' : 'edit',
                          );
                          idItem == null ? await SaveHelper.save(item) : await SaveHelper.save(item, index: index);
                          callback({'name': item.name, 'uid': item.uid});
                          Get.back();
                        }
                      },
                    ),
                  ),
                  Flexible(
                    child: BTN(name: 'انصراف', type: BTNType.cancel, onTap: () => Get.back()),
                  ),
                ],
              ),
              // Text('برای انصراف و لغو به پایین بکشید.')
            ],
          ),
        ),
      ),

      // h: 180,
      title: idItem == null ? 'افزودن دسته‌بندی جدید' : 'ویرایش دسته‌بندی',
    );
  }
}
