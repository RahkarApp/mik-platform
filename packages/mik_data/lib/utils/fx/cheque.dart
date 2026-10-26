// ignore_for_file: unnecessary_null_comparison, dead_code

import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';

import '../../models/models.dart';
import '../saveHelper.dart';
import '../variable.dart';

class ChequeFX {
  static pass(ChequeDB item) async {
    for (var i = 0; i < cheque.length; i++) {
      if (cheque.getAt(i)!.uid == item.uid!) {
        item.status = 1;
        item.backup = 'edit';
        item.desc = '${item.desc!}\n در تاریخ ${DateConvertor.grigoriToJalali(DateTime.now())} پاس شد.';
        await SaveHelper.save(item, index: i);
        Alert.success('چک به وضیعت پاس شده تغییر کرد.');
        break;
      }
    }
    return;
  }

  static delete(ChequeDB item) async {
    if ((socketConnected.value != 'error' && socketConnected.value != 'disconnect')) {
      for (var i = 0; i < bill.length; i++) {
        if (bill.getAt(i)!.uid == item.billUID) {
          await SaveHelper.delete(bill.getAt(i)!, i);
          // break;
        }
      }
      for (var i = 0; i < cheque.length; i++) {
        if (cheque.getAt(i)!.uid == item.uid!) {
          await SaveHelper.delete(cheque.getAt(i)!, i);
          //break;
        }
      }
      Get.back();
      Alert.success('چک با موفقیت حذف شد.');
    } else {
      Alert.error('برای حذف چک باید به سرویس همزمانی‌ اطلاعات متصل باشید.');
    }
    return;
  }

  static String toUID(String to) {
    if (to == null) {
      return '';
    }
    if (to.startsWith('F-')) {
      List<InvoiceDB> f = invoice.values.where((element) => ('${element.uid}' == to.replaceAll('F-', ''))).toList();
      if (f.isNotEmpty) {
        int dis = 0;
        int ex = 0;
        for (var element in f[0].parameters!) {
          if (element['name'] == 'discount') {
            dis += int.tryParse(element['amount'].toString()) ?? 0;
          } else if (element['name'] == 'excess') {
            ex += int.tryParse(element['amount'].toString()) ?? 0;
          }
        }
        return 'بابت فاکتور ${f[0].type == 'buy' ? 'خرید ' : ''}${f[0].id} ${f[0].type == 'buy' ? 'از' : ''} ${PersonFX.findByUID(f[0].personUID).name} به مبلغ:${Price.show(AccountingFX.total(f[0].items!) - dis + ex)}';
      } else {
        return 'نامعلوم';
      }
    } else if (to.startsWith('C-')) {
      var c = cost.values.where((element) => 'C-${element.uid}' == to).toList();
      if (c.isNotEmpty) {
        return 'بابت هزینه ${c[0].name} ${PersonFX.findByUID(c[0].personUID).name} به مبلغ ${Price.show(c[0].price!)}';
      }
      return '';
    } else {
      return '';
    }
  }

  static String to(String to) {
    if (to == null) {
      return '';
    }
    if (to.startsWith('f')) {
      List<InvoiceDB> f = invoice.values.where((element) => ('F-${element.uid}' == to)).toList();
      int dis = 0;
      int ex = 0;
      if (f.isNotEmpty) {
        for (var element in f[0].parameters!) {
          if (element['type'] == 'discount') {
            dis += int.tryParse(element['amount'].toString()) ?? 0;
          } else if (element['type'] == 'excess') {
            ex += int.tryParse(element['amount'].toString()) ?? 0;
          }
        }
        return 'بابت فاکتور ${f[0].type == 'buy' ? 'خرید ' : ''}${f[0].id} ${f[0].type == 'buy' ? 'از' : ''} ${PersonFX.findByUID(f[0].personUID).name} به مبلغ:${Price.show(AccountingFX.total(f[0].items!) - dis + ex)}';
      } else {
        return 'نامعلوم';
      }
    } else if (to.startsWith('c')) {
      var c = cost.values.where((element) => 'c${element.id}' == to).toList();
      if (c.isNotEmpty) {
        return 'بابت هزینه ${c[0].name} ${PersonFX.findByUID(c[0].personUID).name} به مبلغ ${Price.show(c[0].price!)}';
      }
      return '';
    } else {
      return '';
    }
  }

  static List<ChequeDB> find(String to) {
    return cheque.values.where((t) => t.toUID == '' ? t.to == to : t.toUID == to).toList();
  }

  static add({
    required bank,
    required date,
    required dueDate,
    required chequeNo,
    required price,
    required type,
    required mode,
    required holder,
    required payee,
    required holderUID,
    required payeeUID,
    required to,
    required toUID,
    required accNo,
    required branch,
    required branchNo,
    required desc,
    required callback,
  }) async {
    if (bank != null && bank != 0 && date != null && dueDate != null && chequeNo != '' && Price.toInt(price) > 0 && ((type == null && toUID != null) || type != null)) {
      if (mode == 'دریافت چک' && holderUID != '') {
      } else if (mode == 'صدور چک' && payeeUID != '') {
      } else {
        return Alert.error('موارد الزامی را وارد کنید!');
      }

      var bl = BillDB(
        id: ID.newId(bill),
        uid: ID.uidNew(),
        debtor: holder,
        creditor: payee,
        debtorUID: holderUID,
        creditorUID: payeeUID,
        total: 0,
        paid: Price.toInt(price),
        unPaid: 0,
        to: to,
        toUID: toUID,
        date: date,
        deadLine: dueDate,
        type: 'cheque',
        inserter: 0,
        backup: 'new',
        meta: {},
      );
      var ch = ChequeDB(
        id: ID.newId(cheque),
        uid: ID.uidNew(),
        billID: bl.id,
        billUID: bl.uid,
        accNo: accNo,
        bankID: bank,
        branch: branch,
        branchNo: int.tryParse(branchNo) ?? 0,
        chequeNo: chequeNo,
        date: date,
        desc: desc,
        dueDate: dueDate,
        holder: holder,
        payee: payee,
        holderUID: holderUID,
        payeeUID: payeeUID,
        price: Price.toInt(price),
        status: 0,
        to: to,
        toUID: toUID,
        inserter: 0,
        backup: 'new',
      );
      // if (type == null) {
      await SaveHelper.save(bl);
      await SaveHelper.save(ch);

      //   }
      if (to!.startsWith('f') || toUID!.startsWith('F-')) {
        InvoiceDB? f;
        int index = 0;
        for (index = 0; index < invoice.length; index++) {
          if ('f${invoice.getAt(index)!.id}' == to || 'F-${invoice.getAt(index)!.uid}' == toUID) {
            f = invoice.getAt(index)!;
            break;
          }
        }
        if (f != null) {
          f.billUID!.add(bl.uid!);
          var invoiceData = {
            'invoice': f.toJson(),
            'bill': [bl.toJson()],
            'cheque': [ch.toJson()],
            'type': 'edit',
          };
          await SaveHelper.addInvoice(invoiceData);
          // await SaveHelper.save(f, index: index);
        }
      } else if (to!.startsWith('c') || to!.startsWith('C-')) {
        CostDB? c;
        int index = 0;
        for (index = 0; index < cost.length; index++) {
          if ('c${cost.getAt(index)!.id}' == to || 'C-${cost.getAt(index)!.uid}' == toUID) {
            c = cost.getAt(index)!;
            break;
          }
        }
        if (c != null) {
          c.billUID!.add(bl.uid);
          await SaveHelper.save(c, index: index);
        }
      }

      if (type == null) Alert.success('چک با موفقیت ثبت شد.');
      if (type != null) callback(ch);
      return 'ok';
    } else {
      return Alert.error('موارد الزامی را وارد کنید!');
    }
  }

  static edit({
    required billIndex,
    required chequeIndex,
    required bank,
    required date,
    required dueDate,
    required chequeNo,
    required price,
    required type,
    required mode,
    required holder,
    required payee,
    required holderUID,
    required payeeUID,
    required to,
    required toUID,
    required accNo,
    required branch,
    required branchNo,
    required desc,
    required callback,
  }) async {
    if (bank != null && bank != 0 && date != null && dueDate != null && chequeNo != '' && Price.toInt(price) > 0 && ((type == null && toUID != null) || type != null)) {
      if (mode == 'دریافت چک' && holder != 0) {
      } else if (mode == 'صدور چک' && payee != 0) {
      } else {
        return Alert.error('موارد الزامی را وارد کنید!');
      }
      BillDB oldBill = bill.getAt(billIndex)!;

      ChequeDB oldCheque = cheque.getAt(chequeIndex)!;
      var bl = BillDB(
        id: oldBill.id,
        uid: oldBill.uid,
        debtor: holder,
        creditor: payee,
        debtorUID: holderUID,
        creditorUID: payeeUID,
        total: oldBill.total,
        paid: Price.toInt(price),
        unPaid: 0,
        to: oldBill.to,
        toUID: oldBill.toUID,
        date: date,
        deadLine: dueDate,
        type: 'cheque',
        inserter: 0,
        backup: 'edit',
        meta: {},
      );
      var ch = ChequeDB(
        id: oldCheque.id,
        uid: oldCheque.uid,
        billUID: oldBill.uid,
        billID: oldBill.id,
        accNo: accNo,
        bankID: bank,
        branch: branch,
        branchNo: int.tryParse(branchNo) ?? 0,
        chequeNo: chequeNo,
        date: date,
        desc: desc,
        dueDate: dueDate,
        holder: holder,
        payee: payee,
        holderUID: holderUID,
        payeeUID: payeeUID,
        price: Price.toInt(price),
        status: 0,
        to: oldCheque.to,
        toUID: oldCheque.toUID,
        inserter: 0,
        backup: 'edit',
      );

      await SaveHelper.save(bl, index: billIndex);
      await SaveHelper.save(ch, index: chequeIndex);

      if (type == null) Alert.success('چک با موفقیت ویرایش شد.');
      if (type != null) callback(ch);
      return 'ok';
    } else {
      return Alert.error('موارد الزامی را وارد کنید!');
    }
  }
}
