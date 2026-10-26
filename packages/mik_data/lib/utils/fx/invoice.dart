// ignore_for_file: curly_braces_in_flow_control_structures, unused_local_variable

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/input/barcodeInput.dart';
import 'package:mik_components/elements/input/dropdown.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_consts/const.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_pages/invoice/add/components/model.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_utils/private/invoiceStatus.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_utils/public/number.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';

import 'package:persian_number_utility/persian_number_utility.dart';

import '../../models/models.dart';
import '../saveHelper.dart';
import '../variable.dart';

class InvoiceFX {
  static addNew({
    required String date,
    required int personID,
    required String personUID,
    required String type,
    required String cash,
    required int notPaid,
    required double otherPay,
    String? deadLineDate,
    String? invoiceUID, //null=>NEW. /// notNull=>edit
    required List<BillDB> allBill,
    required int tPrice,
    required int paidPrice,
    required List<ChequeDB> chequeList,
    // required List<String> warehouseIds,
    required List<InvoiceItemModel> items,
    // required List<int> products,
    // required List<String> productsUID,
    // required List<int> prices,
    // required List<double> amounts,
    // required List<int> buyPrice,
    // required List<double> vat,
    String? doc,
    required int excess,
    required int discount,
    required int shippingCost,
    String? shippingCompany,
    required status,
    required int commission,
    required int cRecipient,
    required String cRecipientUID,
    required int cStatus,
    String? statusDate,
    String? editDate,
    String? description,
      Map? meta,
    String? trakingCode,
    required String branchUID,
    bool first = false,
  }) async {
    var oinvoice = InvoiceFX.find(invoiceUID);
    if (financialPeriod.length > 0 &&
        (DateTime.parse(date).isBefore(DateTime.parse(financialPeriod.getAt(financialPeriod.length - 1)!.endDate!)) ||
            DateTime.parse(date).compareTo(DateTime.parse(financialPeriod.getAt(financialPeriod.length - 1)!.endDate!)) == 0)) {
      return Alert.error('امکان ثبت فاکتور در دوره قبل وجود ندارد.');
    } else if ((personUID == '' || personUID == '-') && !first) {
      return Alert.info(type == 'buy' ? 'تامین‌کننده را انتخاب کنید.' : 'خریدار را انتخاب کنید');
    }
    //  else if (type != 'buy' && branchUID == '') {
    //   return Alert.error('شعبه را انتخاب کنید.');
    // }
    else if ((cash == '' && type != 'pf') || (cash == '' && type == 'convert')) {
      return Alert.error('نحوه پرداخت و تسویه فاکتور را مشخص کنید.');
    } else if (cash == 'credit' && tPrice - (otherPay + paidPrice).toInt() < 0) {
      return Alert.error('مبلغ پرداخت شده نمیتواند از مبلغ کل بیشتر باشد.');
    } else {
      int iid = oinvoice != null
          ? type == 'convert'
                ? ID.newId(invoice)
                : oinvoice.id!
          : (ID.endId(invoice).toString().startsWith('10000') ? int.parse(ID.endId(invoice).toString().substring(4)) + 1 : ID.newId(invoice));
      String iuid = type == 'convert' ? ID.uidNew(id: iid) : invoiceUID ?? ID.uidNew(id: iid);
      List<String> billUIDItem = [];
      List bills = [];
      List cheques = [];
      int? bid = allBill.isEmpty
          ? bill.length == 0
                ? 1
                : (ID.endId(bill)).toString().startsWith('10000')
                ? int.parse(ID.endId(bill).toString().substring(4)) + 1
                : ID.newId(bill)
          : allBill[0].id;

      if (type != 'pf') {
        BillDB billItem = BillDB(
          id: bid,
          uid: allBill.isEmpty ? ID.uidNew(id: bid) : allBill[0].uid,
          debtor: type == 'buy' ? 0 : personID,
          debtorUID: type == 'buy' ? '' : personUID,
          creditor: type == 'buy' ? personID : 0,
          creditorUID: type == 'buy' ? personUID : '',
          total: tPrice,
          paid: cash == 'online'
              ? 0
              : cash == 'paid'
              ? tPrice
              : paidPrice,
          unPaid: cash == 'online'
              ? double.parse(tPrice.toString())
              : cash == 'paid'
              ? 0.0
              : (tPrice - paidPrice).toDouble(),
          to: 'f$iid',
          toUID: 'F-$iuid',
          date: date,
          deadLine: cash == 'credit' ? deadLineDate : date,
          type: cash,
          inserter: 0,
          meta:meta,
          backup: allBill.isEmpty ? 'new' : allBill[0].backup,
         
        );
        billUIDItem = [billItem.uid!];
        bills.add(billItem.toJson());
        for (var i = 0; i < chequeList.length; i++) {
          int ii = ID.newId(bill) + i + 1;
          int ci = ID.newId(cheque) + i;
          var bl = BillDB(
            id: ii,
            uid: ID.uidNew(id: ii),
            debtor: chequeList[i].holder,
            creditor: chequeList[i].payee,
            debtorUID: chequeList[i].holderUID,
            creditorUID: chequeList[i].payeeUID,
            total: 0,
            paid: chequeList[i].price,
            unPaid: 0,
            to: 'f$iid',
            toUID: 'F-$iuid',
            date: chequeList[i].date,
            deadLine: chequeList[i].dueDate,
            type: 'cheque',
            inserter: 0,
            backup: 'new',
            meta: {},
          );
          var ch = ChequeDB(
            id: ci,
            uid: ID.uidNew(id: ci),
            billID: bl.id,
            billUID: bl.uid,
            accNo: chequeList[i].accNo,
            bankID: chequeList[i].bankID,
            branch: chequeList[i].branch,
            branchNo: chequeList[i].branchNo ?? 0,
            chequeNo: chequeList[i].chequeNo,
            date: chequeList[i].date,
            desc: chequeList[i].desc,
            dueDate: chequeList[i].dueDate,
            holder: chequeList[i].holder,
            payee: chequeList[i].payee,
            holderUID: chequeList[i].holderUID,
            payeeUID: chequeList[i].payeeUID,
            price: chequeList[i].price,
            status: 0,
            to: 'f$iid',
            toUID: 'F-$iuid',
            inserter: 0,
            backup: 'new',
          );
          bills.add(bl.toJson());
          cheques.add(ch.toJson());
          billUIDItem.add(bl.uid!);
        }
      }
      if (oinvoice != null && (type != 'pf' || type == 'convert')) {
        List<String> oldBillUID = List.from(oinvoice.billUID!);
        oldBillUID.removeWhere((element) => billUIDItem.contains(element));
        if (oldBillUID.isNotEmpty) billUIDItem.addAll(oldBillUID);
      }
      var pItems = {};
      for (var i = 0; i < items.length; i++) {
        List pro = [];
        ProductDB p = product.values.firstWhere((e) => e.uid == items[i].uid);
        for (var element in items[i].pro) {
          pro.add({
            "prouid": element.uid,
            "price": element.price,
            "buyPrice": element.buyPrice,
            "amount": element.amount,
            "vat": {"percent": p.vat, "vatCal": true},
            "wuid": element.warehouseUID,
            "parameters": element.parameters,
          });
        }
        pItems[items[i].uid] = pro;
      }
      List statusList = [];
      if (oinvoice != null) {
        statusList.addAll(oinvoice.status); //= oinvoice.status;
        log(statusList.toString());
        log('message: ${statusList.where((e) => e['status'] == status).toList()}');
        if (statusList.where((e) => e['status'] == status).toList().isEmpty) {
          if (type == 'buy' || (type != 'buy' && status != null)) statusList.add({"status": status, "date": DateTime.now().toIso8601String()});
        }
      } else {
        statusList = [
          if (type == 'buy') {"status": status, "date": DateTime.now().toIso8601String()} else if (type != 'buy') {"status": status ?? 1, "date": DateTime.now().toIso8601String()},
        ];
      }
      InvoiceDB inv = InvoiceDB(
        id: iid,
        uid: iuid,
        personUID: personUID,
        branchUID: branchUID,
        items: pItems,
        billUID: billUIDItem,
        date: date,
        doc: doc,
        parameters: [
          {"name": "discount", "amount": discount, "type": "fix", "mode": "ded"},
          {"name": "excess", "amount": excess, "type": "fix", "mode": "add"},
        ],
        type: type,
        shipping: {"cost": shippingCost, "trakingCode": trakingCode, "company": shippingCompany},
        status: statusList,
        commission: {"amount": commission, "status": cStatus, "mikyar": cRecipient},
        description: description ?? '',
        inserter: 0,
        backup: 'new',
      );
      var invoiceData = {'invoice': inv.toJson(), 'bill': bills, 'cheque': cheques, 'type': oinvoice == null || type == 'convert' ? 'add' : 'edit'};
      log(invoiceData.toString());
      //send invoiceData to server
      await SaveHelper.addInvoice(invoiceData);

      ////change product inventory if (type != 'pf')<===> not effective
      ////Edit Warehouse if (type != 'pf')

      if (type == 'convert') {
        for (var i = 0; i < invoice.length; i++) {
          var pf = invoice.getAt(i)!;
          if (pf.uid == oinvoice.uid) {
            pf.description = '${pf.description!}\n تبدیل شده به فاکتور شماره ${inv.id} در تاریخ ${inv.date.toString().toPersianDate()}';
            pf.status!.add({'status': 901, 'date': DateTime.now().toIso8601String()});
            //send invoice to server for EDIT
            var invoiceData = {'invoice': pf.toJson(), 'bill': [], 'cheque': [], 'type': 'edit'};
            await SaveHelper.addInvoice(invoiceData);
            break;
          }
        }
      }
    }
    return 'ok';
  }

  // static add(
  //     {required String date,
  //     required int personID,
  //     required String personUID,
  //     required String type,
  //     required String cash,
  //     required int notPaid,
  //     required double otherPay,
  //     String? deadLineDate,
  //     String? invoiceUID, //null=>NEW. /// notNull=>edit
  //     required List<BillDB> allBill,
  //     required int tPrice,
  //     required int paidPrice,
  //     required List<ChequeDB> chequeList,
  //     required List<String> warehouseIds,
  //     required List<int> products,
  //     required List<String> productsUID,
  //     required List<int> prices,
  //     required List<double> amounts,
  //     required List<int> buyPrice,
  //     required List<double> vat,
  //     String? doc,
  //     required int excess,
  //     required int discount,
  //     required int shippingCost,
  //     String? shippingCompany,
  //     required status,
  //     required int commission,
  //     required int cRecipient,
  //     required String cRecipientUID,
  //     required int cStatus,
  //     String? statusDate,
  //     String? editDate,
  //     String? description,
  //     String? trakingCode,
  //     required String branchUID}) async {
  //   const dataEdit = {
  //     'personUID': 'UID',
  //     'doc': '',
  //     'excess': 0,
  //     'shippingCost': 0,
  //     'status': 0,
  //     'commission': 0,
  //     'cRecipientUID': "UID",
  //     'cStatus': 0,
  //     'discount': 0, //toman
  //     'description': '',
  //     'trakingCode': '',
  //     'shippingCompany': '',
  //     'vat': 0,
  //     'isBuy': false,
  //     'product': [
  //       {'uid': "uid", 'amount': 0, 'price': 0} //....
  //     ],
  //     // 'bill': [
  //     //   {
  //     //     'uid': "UID",
  //     //     'act': 'new or edit or delete',
  //     //     'total': 0,
  //     //     'paid': 0,
  //     //     'unPaid': 0,
  //     //     'deadLine': 'date',
  //     //   } //....
  //     // ],
  //     // 'cheque': [
  //     //   {
  //     //     'uid': "UID",
  //     //     'act': 'new or delete',
  //     //     'billUID': "UID",
  //     //     'bank': '',
  //     //     'date': 'date',
  //     //     'dueDate': 'date',
  //     //     'chequeNo': 0,
  //     //     'price': 0,
  //     //     'accNo': 0,
  //     //     'branch': '',
  //     //     'branchNo': 0,
  //     //     'desc': ''
  //     //   } //....
  //     // ]
  //   };
  //   var oinvoice = InvoiceFX.find(invoiceUID);

  //   if (financialPeriod.length > 0 &&
  //       (DateTime.parse(date).isBefore(DateTime.parse(financialPeriod.getAt(financialPeriod.length - 1)!.endDate!)) ||
  //           DateTime.parse(date).compareTo(DateTime.parse(financialPeriod.getAt(financialPeriod.length - 1)!.endDate!)) == 0)) {
  //     return Alert.error('امکان ثبت فاکتور در دوره قبل وجود ندارد.');
  //   } else if (personID == 0) {
  //     return Alert.info(type == 'buy' ? 'تامین‌کننده را انتخاب کنید.' : 'خریدار را انتخاب کنید');
  //   } else if (type != 'buy' && branchUID == '') {
  //     return Alert.error('شعبه را انتخاب کنید.');
  //   } else if ((cash == '' && type != 'pf') || (cash == '' && type == 'convert')) {
  //     return Alert.error('نحوه پرداخت و تسویه فاکتور را مشخص کنید.');
  //   } else if (cash == 'credit' && tPrice - (otherPay + paidPrice).toInt() < 0) {
  //     return Alert.error('مبلغ پرداخت شده نمیتواند از مبلغ کل بیشتر باشد.');
  //   } else {
  //     int iid = oinvoice != null ? oinvoice.id! : (ID.endId(invoice).toString().startsWith('10000') ? int.parse(ID.endId(invoice).toString().substring(4)) + 1 : ID.newId(invoice));
  //     String iuid = type == 'convert' ? ID.uidNew(id: iid) : invoiceUID ?? ID.uidNew(id: iid);

  //     List<String> billUIDItem = [];
  //     BillDB billItem = BillDB(
  //       uid: '',
  //       toUID: '',
  //       debtorUID: '',
  //       creditorUID: '',
  //       inserter: 0,
  //     );
  //     if (type != 'pf') {
  //       billItem = BillDB(
  //           id: allBill.isEmpty
  //               ? bill.length == 0
  //                   ? 1
  //                   : (ID.endId(bill)).toString().startsWith('10000')
  //                       ? int.parse(ID.endId(bill).toString().substring(4)) + 1
  //                       : ID.newId(bill)
  //               : allBill[0].id,
  //           uid: allBill.isEmpty ? ID.uidNew() : allBill[0].uid,
  //           debtor: type == 'buy' ? 0 : personID,
  //           creditor: type == 'buy' ? personID : 0,
  //           debtorUID: type == 'buy' ? '' : personUID,
  //           creditorUID: type == 'buy' ? personUID : '',
  //           total: tPrice,
  //           paid: cash == 'online'
  //               ? 0
  //               : cash == 'paid'
  //                   ? tPrice
  //                   : paidPrice,
  //           unPaid: cash == 'online'
  //               ? double.parse(tPrice.toString())
  //               : cash == 'paid'
  //                   ? 0.0
  //                   : (tPrice - paidPrice).toDouble(),
  //           to: 'f$iid',
  //           toUID: 'F-$iuid',
  //           date: date,
  //           deadLine: cash == 'credit' ? deadLineDate : date,
  //           type: cash,
  //           inserter: 0,
  //           backup: allBill.isEmpty ? 'new' : allBill[0].backup);
  //       billUIDItem = [billItem.uid!];
  //       await SaveHelper.save(billItem, index: oinvoice == null ? null : BillFX.findIndex(billItem.uid!));
  //       for (var i = 0; i < chequeList.length; i++) {
  //         ChequeFX.add(
  //           bank: chequeList[i].bankID,
  //           date: chequeList[i].date,
  //           dueDate: chequeList[i].dueDate,
  //           chequeNo: chequeList[i].chequeNo,
  //           price: chequeList[i].price,
  //           type: 'sell',
  //           mode: 'دریافت چک',
  //           holder: chequeList[i].holder,
  //           payee: chequeList[i].payee,
  //           holderUID: chequeList[i].holderUID,
  //           payeeUID: chequeList[i].payeeUID,
  //           to: 'f$iid',
  //           toUID: 'F-$iuid', //,
  //           accNo: chequeList[i].accNo,
  //           branch: chequeList[i].branch,
  //           branchNo: chequeList[i].branchNo,
  //           desc: chequeList[i].desc,
  //           callback: (ChequeDB v) {
  //             billUIDItem.add(v.billUID!);
  //           },
  //         );
  //       }
  //     }
  //     if (oinvoice != null && (type != 'pf' || type == 'convert')) {
  //       List<String> oldBillUID = List.from(oinvoice.billUID);
  //       oldBillUID.removeWhere((element) => billUIDItem.contains(element));
  //       if (oldBillUID.isNotEmpty) billUIDItem.addAll(oldBillUID);
  //     }
  //     InvoiceDB inv = InvoiceDB(id: iid, uid: iuid, personUID: personUID, items: items, billUID: billUIDItem, date: date, type: type, status: status, inserter: 0);

  //     // FactorDB inv = FactorDB(
  //     //     id: iid,
  //     //     billID: [],
  //     //     billUID: billUIDItem,
  //     //     productID: products,
  //     //     productUID: productsUID,
  //     //     amount: amounts,
  //     //     buyPrice: buyPrice,
  //     //     sellPrice: prices,
  //     //     vat: vat,
  //     //     date: date,
  //     //     personID: personID,
  //     //     personUID: personUID,
  //     //     doc: doc,
  //     //     isBuy: type == 'buy',
  //     //     excess: excess,
  //     //     shippingCost: shippingCost,
  //     //     shippingCompany: shippingCompany,
  //     //     status: status,
  //     //     statusDate: statusDate,
  //     //     editDate: editDate,
  //     //     commission: commission,
  //     //     cStatus: cStatus,
  //     //     cRecipient: cRecipient,
  //     //     cRecipientUID: cRecipientUID,
  //     //     discount: discount,
  //     //     isDiscountFixed: true,
  //     //     description: description,
  //     //     uuid: iuid,
  //     //     trakingCode: trakingCode,
  //     //     type: type == 'buy' ? 'buy' : 'B|$branchUID',
  //     //     vatCalculated: true,
  //     //     inserter: 0,
  //     //     backup: invoiceUID == null || type == 'convert' ? 'new' : 'edit');

  //     await SaveHelper.save(inv, index: invoiceUID == null ? null : InvoiceFX.findIndex(invoiceUID));
  //     //Edit Inventory

  //     if (type != 'pf') {
  //       var invoiceProduct = product.values.where((element) => inv.productUID!.contains(element.uid)).toList();
  //       for (var i = 0; i < inv.productUID!.length; i++) {
  //         var thisItem = invoiceProduct.where((element) => element.uid == inv.productUID![i]).toList();
  //         thisItem.first.inventory = type == 'buy' ? thisItem.first.inventory! + inv.amount![i] : thisItem.first.inventory! - inv.amount![i];
  //         int indexPr = product.values.toList().indexWhere((element) => element.uid == thisItem.first.uid);
  //         await SaveHelper.save(thisItem.first, index: indexPr);
  //       }
  //     }
  //     //Edit Warehouse
  //     if (type != 'pf') {
  //       WarehouseFX.IW(invoiceUID: iuid, warehouseUID: warehouseIds, puid: productsUID, proUID: products.map((e) => '').toList(), amount: amounts, type: type == 'buy' ? "I2W" : "W2I");
  //     }

  //     //Edit PreInvoice
  //     if (type == 'convert') {
  //       for (var i = 0; i < invoice.length; i++) {
  //         var pf = invoice.getAt(i)!;
  //         if (pf.uid == oinvoice.uid) {
  //           pf.description = '${pf.description!}\n تبدیل شده به فاکتور شماره ${inv.id} در تاریخ ${inv.date.toString().toPersianDate()}';
  //           pf.status!.add({'status': 901, 'date': DateTime.now().toIso8601String()});
  //           await SaveHelper.save(pf, index: i);
  //           break;
  //         }
  //       }
  //     }
  //   }
  //   //bill OK
  //   //invoice OK
  //   //cheque OK
  //   //warehouse OK
  //   //warehoseHistory OK
  //   //inventory OK
  //   //SMS OK
  //   return 'ok';
  // }

  static bool existPro(puid, p) {
    List<ProductProDB> d = productPro.values.where((r) => r.productUID == puid && r.property!.where((w) => w['uid'] == p['uid'] && w['vid'] == p['vid']).toList().isNotEmpty).toList();
    for (var i = 0; i < d.length; i++) {
      List<InvoiceDB> inv = invoice.values.where((w) => w.items!.keys.contains(d[i].productUID) && w.items![d[i].productUID].toList().where((s) => s['prouid'] == d[i].uid).isNotEmpty).toList();
      if (inv.isNotEmpty) return true;
    }
    return false;
  }

  static findIndex(uid) {
    for (var i = 0; i < invoice.length; i++) {
      if (invoice.getAt(i)!.uid == uid) {
        return i;
      }
    }
  }

  static find(uid) {
    if (uid == null || uid == '') return null;
    var f = invoice.values.where((e) => e.uid == uid).toList();
    if (f.isNotEmpty) {
      return f[0];
    } else
      return null;
  }

  static String typeInvoice(item) {
    return item.status == 901 ? 'pf' : item.type;
  }

  static String toTypeMode(type) {
    return type == null || type == ''
        ? 'جدید'
        : type == 'buy'
        ? 'خرید'
        : type == 'pf'
        ? 'پیش‌فاکتور'
        : 'فروش';
  }

  static String toType(typeMode) {
    return typeMode == 'جدید'
        ? 'new'
        : typeMode == 'خرید'
        ? 'buy'
        : typeMode == 'پیش‌فاکتور'
        ? 'pf'
        : 'sell';
  }

  static String pageTitle(item, type) {
    return item == null
        ? (type == null || type == 'new')
              ? 'فاکتور جدید'
              : type == 'buy'
              ? 'فاکتور خرید'
              : type == 'pf'
              ? 'پیش‌فاکتور'
              : 'فاکتور فروش'
        : type == 'buy'
        ? 'ویرایش فاکتور خرید ${item!.id}'
        : type == 'pf'
        ? 'ویرایش پیش‌فاکتور'
        : type == 'convert'
        ? 'تبدیل به فاکتور فروش'
        : 'ویرایش فاکتور فروش ${item!.id}';
  }

  static bool isPaid(List billUID) {
    var thisBill = bill.values.where((element) => billUID.contains(element.uid)).toList();
    double paid = 0.0;
    for (var i = 0; i < thisBill.length; i++) {
      paid = paid + thisBill[i].paid!;
    }

    return thisBill.isNotEmpty ? (thisBill.first.total ?? 0) <= paid : false;
  }

  static onClickStatus(int status, item, paid, twoBack, callback) async {
    if (socketConnected.value == 'error' || socketConnected.value == 'disconnect') {
      return Alert.warning('برای تغییر وضعیت فاکتور باید به سروریس‌همزمانی‌اطلاعات متصل باشید.');
    }
    callback(true);

    InvoiceDB? thisInvoice;
    int index = -1;
    for (var i = 0; i < invoice.length; i++) {
      var it = invoice.getAt(i);
      if (it!.uid == item.uid) {
        thisInvoice = it;
        index = i;
        break;
      }
    }
    if (!thisInvoice!.status!.map((y) => y['status']).toList().contains(status)) {
      if (status == 3) {
        bool open = false;

        //Get.back();
        if (AccountingFX.invoicePrice(item) - paid > 0) {
          await MyBottomSheet.viewAsync(
            Column(
              children: [
                Text(
                  'فاکتور مورد نظر تسویه نشده و مبلغ ${Number.addCommas((AccountingFX.invoicePrice(item) - paid).toStringAsFixed(0))} تومان بدهکار است.\nاز ارسال سفارش اطمینان دارید؟',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: BTN(
                        wait: false,
                        onTap: () {
                          open = true;
                          Get.back();
                        },
                        icon: IconsaxPlusLinear.tick_square,
                        name: 'ادامه',
                      ),
                    ),
                    Flexible(
                      child: BTN(
                        wait: false,
                        name: 'انصراف',
                        type: BTNType.cancel,
                        onTap: () async {
                          open = false;
                          Get.back();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            header: 'فاکتور تسویه نشده',
            h: 220,
          );
        } else {
          open = true;
        }
        //Get.back();
        if (open) {
          await sendOrder(thisInvoice, status, twoBack: twoBack);
        }
      } else {
        if (thisInvoice.type == 'buy' && status == 444) {
          thisInvoice.status!.add({'status': status, 'date': DateTime.now().toIso8601String()});
          var invoiceData = {'invoice': thisInvoice.toJson(), 'bill': [], 'cheque': [], 'type': 'edit'};
          await SaveHelper.addInvoice(invoiceData);
          if (twoBack ?? true) Get.back();
          Alert.success('حذف فاکتور با موفقیت انجام شد.');
        } else if ((status != 100 || (status == 100 && InvoiceStatus.findLastStatusCode(item.status) == 3))) {
          if ((status == 8 || status == 9) && DateTime.parse(InvoiceStatus.findLastStatusDate(item.status)).add(Duration(days: settings!.dayForCancel!)).difference(DateTime.now()).inMinutes < 0) {
            if (twoBack ?? true) Get.back();
            return Alert.error('مهلت مرجوع یا لغو کردن فاکتور به پایان رسیده است!');
          }
          thisInvoice.status!.add({'status': status, 'date': DateTime.now().toIso8601String()});
          var invoiceData = {'invoice': thisInvoice.toJson(), 'bill': [], 'cheque': [], 'type': 'edit'};
          await SaveHelper.addInvoice(invoiceData);
          if (twoBack ?? true) Get.back();
        } else {
          Alert.info('سفارش ابتدا باید به وضعیت «ارسال شده»\nو سپس «تحویل شده» تبدیل گردد.');
        }
      }
    }
    AccountingFX.balance();
    callback(false);
    callback('change');
  }

  static deleteBuyInvoice(context, InvoiceDB inv, double paid, bool twoBack, callback) {
    Map<dynamic, dynamic> items = inv.items!;
    String wuid = warehouseName.getAt(0)!.uid!;
    List np = [];
    List anp = [];
    List<InvoiceItemModel> data = [];
    for (var key in items.keys) {
      var item = items[key];
      for (var it in item) {
        double inventory = ProductFX.productInWarehouse(key, it['prouid'], wuid);
        double allInventory = ProductFX.productInAllWarehouse(key, prouid: it['prouid'] == '-' ? null : it['prouid']);
        var pr = ProductFX.findUID(key);
        if (allInventory < it['amount']) {
          anp.add({'name': '${pr.name}${it['prouid'] != '-' ? ' - ${ProductFX.proName(key, it['prouid'])}' : ''}', 'uid': key, 'prouid': it['prouid'], 'needAmount': it['amount'] - inventory});
        } else if (inventory < it['amount']) {
          np.add({'name': '${pr.name}${it['prouid'] != '-' ? ' - ${ProductFX.proName(key, it['prouid'])}' : ''}', 'uid': key, 'prouid': it['prouid'], 'needAmount': it['amount'] - inventory});
          var indx = data.indexWhere((e) => e.uid == key);
          InvoiceProItemModel pro = InvoiceProItemModel(uid: it['prouid'], amount: it['amount'] - inventory, price: 0, buyPrice: 0, warehouseUID: '', parameters: []);
          if (indx > -1) {
            data[indx].pro.add(pro);
          } else {
            data.add(InvoiceItemModel(id: pr.id, uid: key, pro: [pro], name: pr.name, barcode: pr.barcode, type: pr.type));
          }
        }
      }
    }
    if (anp.isNotEmpty || np.isNotEmpty) {
      MyBottomSheet.view(
        context,
        child: (s) => anp.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('موارد زیر: '),
                  for (int i = 0; i < np.length; i++) MyDivider(text: np[i]['name'], entText: Number.addCommas(np[i]['needAmount'])),
                  Text('در انبار مرکزی به تعداد مشخص شده نسبت به فاکتور کسری دارند.'),
                  Text('برای حذف فاکتور باید تمام محصولات به تعداد فاکتور در انبار مرکزی وجود داشته باشند.'),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Flexible(
                        flex: 3,
                        child: BTN(
                          navigate: true,
                          disabled: true,
                          onTap: () {},
                          name: 'انتقال محصولات به انبار مرکزی',
                        ),
                      ),
                      Flexible(
                        child: BTN(
                          onTap: () {
                            Get.back();
                            callback('');
                          },
                          borderOnly: true,
                          name: 'انصراف',
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('موارد زیر: '),
                  for (int i = 0; i < anp.length; i++) MyDivider(text: anp[i]['name'], entText: Number.addCommas(anp[i]['needAmount'])),
                  Text('به تعداد مشخص شده نسبت به فاکتور کسری دارند.'),
                  Text('شما محصولات این فاکتور را فروخته‌اید و امکان حذف این فاکتور وجود ندارد.'),
                  Text('میتوانید فاکتور را ویرایش کنید.'),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Flexible(
                        flex: 3,
                        child: BTN(
                          navigate: true,
                          onTap: () async {
                            await Get.toNamed(RoutesName.INVOICEADD, arguments: {'type': InvoiceFX.typeInvoice(inv), 'item': inv});
                            Get.back();
                          },
                          name: 'ویرایش فاکتور خرید',
                        ),
                      ),
                      Flexible(
                        child: BTN(
                          onTap: () {
                            Get.back();
                            callback('');
                          },
                          borderOnly: true,
                          name: 'انصراف',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        title: 'امکان حذف فاکتور وجود ندارد',
      );
    } else {
      Confirm.con(
        context,
        onTapConfirm: () async {
          await onClickStatus(444, inv, paid, twoBack, (v) {
            callback(v);
            Get.back();
          });
        },
        confirmText: 'حذف فاکتور',
        type: ConfirmType.DELETE,
      );
    }
  }

  static sendOrder(thisFactor, status, {twoBack, edit = false, callback}) async {
    final shippingCost = TextEditingController();
    final shippingCostF = FocusNode();
    final trakingCode = TextEditingController();
    final shippingCompany = TextEditingController();
    if ((thisFactor.shipping['cost'] != null && thisFactor.shipping['cost'] != 0) || thisFactor.shipping['trakingCode'] != '') {
      shippingCost.text = Price.showWithCurrency(thisFactor.shipping['cost']);
      trakingCode.text = thisFactor.shipping['trakingCode'] ?? '';
      shippingCompany.text = thisFactor.shipping['company'] ?? '';
    }
    shippingCostF.requestFocus();
    await MyBottomSheet.view(
      Get.context,
      child: (ScrollController scrollController) => Column(
        children: [
          PriceInput(name: 'هزینه پرداختی بابت ارسال', focusNode: shippingCostF, fillColor: darkMode.isFalse ? Colors.grey.shade300 : null, controller: shippingCost),
          Dropdown(
            name: 'شرکت ارسال کننده',
            items_String: shippingCompanyName,
            search: false,
            onChange: (value) {
              shippingCompany.text = value;
            },
          ),
          BarcodeInput(
            controller: trakingCode,
            name: 'بارکد رهگیری سفارش',
            fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
            onChanged: (v) {
              trakingCode.text = v;
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: BTN(
                  name: edit ? 'ویرایش جزئیات' : 'ثبت جزئیات',
                  type: BTNType.ok,
                  onTap: () async {
                    thisFactor!.status.add({'status': status, 'date': DateTime.now().toIso8601String()});
                    if (shippingCompany.text.isNotEmpty) {
                      thisFactor.shipping['company'] = shippingCompany.text;
                    }
                    if (trakingCode.text.isNotEmpty) {
                      thisFactor.shipping['trakingCode'] = trakingCode.text;
                    }
                    if (shippingCost.text.isNotEmpty) {
                      thisFactor.shipping['cost'] = Price.toInt(shippingCost.text);
                    }

                    List<String> warehouse = [];
                    List<WarehouseHistoryDB> whl = warehouseHistory.values.where((w) => thisFactor!.type == 'buy' ? w.from == thisFactor.uid : w.to == thisFactor.uid).toList();
                    // for (var i = 0; i < thisFactor.productUID!.length; i++) {
                    //   WarehouseHistoryDB w = whl.where((t) => t.puid == thisFactor!.productUID![i]).toList()[0];
                    //   warehouse.add(thisFactor.isBuy! ? w.to : w.from);
                    // }
                    var invoiceData = {'invoice': thisFactor.toJson(), 'bill': [], 'cheque': [], 'type': 'edit'};
                    await SaveHelper.addInvoice(invoiceData);
                    // fastReportHomeController.init();
                    if (callback != null) callback(thisFactor);
                    if (twoBack ?? true) Get.back();
                    Get.back();
                    Alert.success('تغییر وضیعت اعمال شد.');
                  },
                ),
              ),
              Flexible(
                child: BTN(name: 'انصراف', type: BTNType.cancel, onTap: () => Get.back()),
              ),
            ],
          ),
        ],
      ),
      title: 'جزئیات ارسال',
    );
  }

  static onClickCommissionStatus(status, item, callback) async {
    InvoiceDB? thisInvoice;
    int index = -1;
    for (var i = 0; i < invoice.length; i++) {
      var it = invoice.getAt(i);
      if (it!.uid == item.uid) {
        thisInvoice = it;
        index = i;
      }
    }
    if (thisInvoice!.commission!['status'] != status && thisInvoice.commission!['status'] == 0) {
      thisInvoice.commission!['status'] = status;
      await SaveHelper.save(thisInvoice, index: index);

      var cs = '';
      if (status == 1) {
        cs = 'W';
        CommissionDB data = CommissionDB(
          id: ID.newId(commission),
          uid: ID.uidNew(),
          personID: thisInvoice.commission!['mikyar'],
          factorID: thisInvoice.id,
          factorUID: thisInvoice.uid,
          amount: thisInvoice.commission!['amount'],
          type: 'commission',
          inserter: 0,
          date: DateTime.now().toIso8601String(),
          description: '',
        ); // 'از فاکتور شماره ' + thisFactor.id.toString());

        await SaveHelper.save(data);
      }
      BillDB billItem = BillDB(
        id: bill.length == 0
            ? 1
            : (ID.endId(bill)).toString().startsWith('10000')
            ? int.parse((ID.endId(bill)).toString().substring(4)) + 1
            : ID.newId(bill),
        uid: ID.uidNew(),
        debtor: 0,
        creditor: thisInvoice.commission!['mikyar'],
        debtorUID: '',
        creditorUID: 'mikyar',
        total: double.parse(thisInvoice.commission.toString()),
        paid: double.parse(thisInvoice.commission.toString()),
        to: "cf$cs${thisInvoice.id}",
        toUID: "CF$cs-${thisInvoice.uid}",
        date: DateTime.now().toIso8601String(),
        deadLine: DateTime.now().toIso8601String(),
        inserter: 0,
        type: 'cash',
        meta: {},
      );
      await SaveHelper.save(billItem);
    }
    callback('change');
  }

  static price(item) {
    num price = 0;
    for (var i = 0; i < item.items.keys.toList().length; i++) {
      var puid = item.items.keys.toList()[i];
      var items = item.items[puid];
      for (var j = 0; j < items.length; j++) {
        price += (items[j]['price'] * items[j]['amount']);
      }
    }
    return price;
  }

  static totalPrice(InvoiceDB inv) {
    int tot = AccountingFX.total(inv.items!);
    var par = inv.parameters;
    int t = tot;
    if (par != null) {
      for (var i = 0; i < par.length; i++) {
        if (par[i]['mode'] == 'add') {
          if (par[i]['mode'] == 'fix') {
            t += int.tryParse(par[i]['amount'].toString()) ?? 0;
          } else {
            t += tot * (double.tryParse(par[i]['amount'].toString()) ?? 0) ~/ 100;
          }
        } else if (par[i]['mode'] == 'ded') {
          if (par[i]['mode'] == 'fix') {
            t -= int.tryParse(par[i]['amount'].toString()) ?? 0;
          } else {
            t -= tot * (double.tryParse(par[i]['amount'].toString()) ?? 0) ~/ 100;
          }
        }
      }
    }
    return t;
  }

  static unPaid(InvoiceDB inv) {
    var b = AccountingFX.allBill(inv.billUID!);

    int tp = 0;

    for (var i = 0; i < b.length; i++) {
      tp = tp + b[i].paid!.toInt();
    }
    if (b.isNotEmpty) {
      return b[0].total!.toInt() - tp;
    } else
      return totalPrice(inv);
  }

  static lastDate(String uid) {
    var latest = invoice.values.where((element) => element.personUID == uid).toList();
    return latest.isNotEmpty ? latest[latest.length - 1].date : null;
  }

  static firstDate(String uid) {
    var latest = invoice.values.where((element) => element.personUID == uid).toList();
    return latest.isNotEmpty ? latest[0].date : null;
  }

  static int findCommission({required List<InvoiceItemModel> items, int? tPrice, int? discount}) {
    num cm = 0;
    for (var i = 0; i < items.length; i++) {
      ProductDB p = product.values.firstWhere((e) => e.uid == items[i].uid);
      for (var element in items[i].pro) {
        if (p.commission != null) {
          if (p.isCommissionFixed!) {
            cm += (p.commission! * element.amount);
          } else {
            cm += (((p.commission! / 100) * element.price) * element.amount);
          }
        }
      }
    }
    if (tPrice != null && tPrice > 0 && discount != null && discount > 0) {
      int t = tPrice + discount;
      cm = (tPrice * cm) / t;
    }
    return cm.toInt();
  }

  static findMikyar(id) {
    if (id == 0) {
      return 'مدیر';
    } else {
      var l = mikyar.values.where((m) => m.id == id).toList();
      if (l.isNotEmpty) return '${l[0].name}';
    }
  }

  static String findInvoiceType(String type, int inserter) {
    if (type == 'buy') {
      if (inserter == 0) {
        return 'خرید-مدیر';
      } else {
        var l = mikyar.values.where((m) => m.id == inserter).toList();
        if (l.isNotEmpty) return 'خرید-${l[0].name}';
      }
    }
    List t = type.split('|');
    String txt = '';
    switch (t[0]) {
      case 'pf':
        txt = 'پیش‌فاکتور';
      case 'app':
        txt = 'اپلیکیشن';
      case 'B':
        txt = 'شعبه';
      case 'S':
        txt = 'سایت';
      case 'M':
        txt = 'مارکت‌پلیس';
        break;
      default:
    }
    if (t.length > 1) {
      if (t[1].toString().split('-').length == 5) {
        var b = branch.values.where((c) => c.uid == t[1]).toList();
        if (b.isNotEmpty) txt += ' ${b[0].name}';
      } else {
        switch (t[1]) {
          case 'woo':
            txt += '-وردپرس';
          case 'digikala':
            txt += '-دیجی‌کالا';
          case 'basalam':
            txt += '-باسلام';
            break;
          default:
        }
      }
    }

    if (t[0] == 'B') {
      if (inserter == 0) {
        txt += '-مدیر';
      } else {
        var l = mikyar.values.where((m) => m.id == inserter).toList();
        if (l.isNotEmpty) txt += '-${l[0].name}';
      }
    }

    return txt;
  }


  static discountPrice(InvoiceDB inv) {
    int total = totalPrice(inv);
    double discount = 0;
    if (inv.parameters != null) {
      var d = inv.parameters!.where((p) => p['name'] == 'discount').forEach((parm) {
        discount += parm['amount'];
      });
    }
    return discount;
  }

  static excessPrice(InvoiceDB inv) {
    int total = totalPrice(inv);
    double excess = 0;
    if (inv.parameters != null) {
      var d = inv.parameters!.where((p) => p['name'] == 'excess').forEach((parm) {
        excess += parm['amount'];
      });
    }
    return excess;
  }
}
