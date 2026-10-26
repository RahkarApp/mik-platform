import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/saveHelper.dart';
import 'package:mik_pages/invoice/components/invoiceItem.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';

import '../../models/models.dart';
import '../variable.dart';

class PersonFX {
  static findByID(id) {
    if (id != 0) {
      return person.values.where((element) => element.id == id).toList()[0];
    } else {
      return PersonDB(name: 'اول دوره', uid: '', inserter: 0);
    }
  }

  static findByUID(uid) {
    if (uid != null && uid != '' && uid != '-') {
      return person.values.where((element) => element.uid == uid).toList()[0];
    } else {
      return PersonDB(name: 'اول دوره', uid: '', inserter: 0);
    }
  }

  static String position(item) {
    String pr = '';
    try {
      if (item.isAdmin) {
        pr = "مدیر";
      } else if (item.isPartner) {
        pr = "شریک";
      } else if (item.isSupplier) {
        pr = "تامین‌ کننده";
      } else if (item.isMarketer) {
        pr = "بازاریاب/پرسنل";
      } else if (item.isCustomer) {
        pr = "مشتری";
      } else if (item.isService) {
        pr = "سرویس دهنده";
      }
      if (item.org) {
        pr += " حقوقی";
      }
      // ignore: empty_catches
    } catch (e) {}

    return pr;
    // return item.name + pr;
  }

  static csHistory(context, String uid, type) {
    var fct = invoice.values.where((e) => e.personUID == uid).toList();
    if (fct.isEmpty) {
      return Alert.warning('سابقه‌ای یافت نشد...');
    }
    var tprice = 0.0;
    for (var a in fct) {
      tprice += (a.status!.every((t) => 3 >= t['status']) ? AccountingFX.total(a.items!) : 0);
    }

    MyBottomSheet.view(
      context,
      child: (scrollController) => Obx(
        () => Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مجموع خرید:',
                  style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
                const Flexible(child: Divider(indent: 10, endIndent: 10, color: Colors.grey)),
                Text(
                  Price.showWithCurrency(tprice),
                  style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'اولین فاکتور:',
                  style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
                const Flexible(child: Divider(indent: 10, endIndent: 10, color: Colors.grey)),
                Text(
                  DateConvertor.toDuration(InvoiceFX.firstDate(uid)),
                  style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'آخرین فاکتور:',
                  style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
                const Flexible(child: Divider(indent: 10, endIndent: 10, color: Colors.grey)),
                Text(
                  DateConvertor.toDuration(InvoiceFX.lastDate(uid)),
                  style: TextStyle(color: darkMode.isTrue ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 10),
              height: (Get.height * 0.5),
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.zero,
                itemCount: fct.length,
                itemBuilder: (BuildContext context, index) {
                  return InvoiceItem(item: fct[index], callback: (v) {}, end: fct.length == index + 1, endList: fct.length == index + 1);
                },
              ),
            ),
          ],
        ),
      ),
      title: type == 'customer' ? 'سوابق مشتری' : 'سوابق تامین‌کننده',
    );
  }

  static add({
    required String name,
    String? nationalID,
    required String mobile,
    String? instagram,
    String? email,
    String? cardNumber,
    String? shebaNumber,
    String? address,
    bool? isAdmin,
    bool? isSupplier,
    bool? isPartner,
    bool? isCustomer,
    bool? isMarketer,
    bool? isService,
    String? description,
    int? stateID,
    int? townID,
    required String orgName,
    required bool org,
    String? tel,
    String? economicID,
    String? postalCode,
    String? uid,
    int? id,
  }) async {
    if (org == true && orgName.isEmpty) {
      return Alert.error('نام شرکت الزاما باید وارد شود.');
    } else if (name.isEmpty) {
      return Alert.error('نام‌و‌نام‌خانوادگی الزاما باید وارد شود.');
    } else if (mobile.isEmpty) {
      return Alert.error('موبایل الزاما باید وارد شود.');
    } else if (!(isPartner! || isSupplier! || isService! || isCustomer!)) {
      return Alert.error('حداقل باید یک نقش کاربری برای فرد مشخص کنید.');
    } else if (!mobile.startsWith('09') || mobile.length != 11) {
      return Alert.error('موبایل را بدرستی وارد کنید.');
    } else {
      PersonDB p = PersonDB(
        id: id ?? ID.newId(person),
        uid: uid ?? ID.uidNew(),
        date: DateTime.now().toIso8601String(),
        name: name,
        nationalID: nationalID,
        mobile: mobile,
        instagram: instagram,
        email: email,
        cardNumber: cardNumber,
        shebaNumber: shebaNumber,
        address: address,
        isAdmin: isAdmin,
        isSupplier: isSupplier,
        isPartner: isPartner,
        isCustomer: isCustomer,
        isMarketer: false,
        isService: isService,
        description: description,
        stateID: stateID,
        townID: townID,
        orgName: orgName,
        org: org,
        tel: tel,
        economicID: economicID,
        postalCode: postalCode,
        inserter: 0,
        backup: uid == null ? 'new' : 'edit',
      );
      int index = -1;
      for (var i = 0; i < person.length; i++) {
        PersonDB? it = person.getAt(i);
        if (uid != null && it!.uid == uid) {
          index = i;
        }
        if (it!.mobile == mobile) {
          if (uid != null) {
            // return Messages.info(
            //  'تلفن همراه تکراری است.\nاحتمالا این فرد با نام دیگری قبلا افزوده شده است.');
          } else {
            return Alert.info('تلفن همراه تکراری است.\nاحتمالا این فرد با نام دیگری قبلا افزوده شده است.');
          }
        }
      }
      var res = await SaveHelper.save(p, index: index);
      return p;
      //jsonDecode(res);
    }
  }
}
