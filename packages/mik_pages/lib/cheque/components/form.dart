// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/bankInput.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/factorCostInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/personInput.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/cheque.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_utils/public/banks.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';

import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:shamsi_date/shamsi_date.dart';

class ChequeAddForm extends StatefulWidget {
  ChequeDB? item;
  ScrollController? controller;
  ChequeAddForm({
    super.key,
    this.controller,
    this.item,
    this.type,
    this.add,
    this.pname,
    this.pid,
    this.puid,
    this.to,
    this.toUID,
    this.callback,
  });
  bool? add;
  String? type;
  String? pname;
  int? pid;
  String? puid;
  var callback;
  String? date, dueDate, to, toUID;

  @override
  State<ChequeAddForm> createState() => _ChequeAddFormState();
}

class _ChequeAddFormState extends State<ChequeAddForm> {
  ChequeDB? item;
  ScrollController? controller;
  bool? add;
  String? type;
  String? pname;
  int? pid;
  String? puid;
  var callback;
  String? date, dueDate, to, toUID;

  RxInt holder = 0.obs, payee = 0.obs;

  RxString holderUID = '-'.obs, payeeUID = '-'.obs;

  final holderCtl = TextEditingController(),
      payeeCtl = TextEditingController(),
      bankCtl = TextEditingController(),
      branchCtl = TextEditingController(),
      branchNoCtl = TextEditingController(),
      dateCtl = TextEditingController(),
      dueDateCtl = TextEditingController(),
      chequeNoCtl = TextEditingController(),
      accNoCtl = TextEditingController(),
      priceCtl = TextEditingController(),
      toCtl = TextEditingController(),
      descCtl = TextEditingController();

  int? billIndex, chequeIndex;

  RxString mode = 'دریافت چک'.obs;

  int? bank;
  @override
  void initState() {
    date = Jalali.now().toDateTime().toIso8601String();
    dateCtl.text = DateConvertor.jalaliNow();
    item = widget.item;
    controller = widget.controller;
    add = widget.add;
    type = widget.type;
    pname = widget.pname;
    pid = widget.pid;
    puid = widget.puid;
    callback = widget.callback;
    // date = widget.date;
    dueDate = widget.dueDate;
    to = widget.to;
    toUID = widget.toUID;

    init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      physics: (type != null)
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          if (type == null)
            Container(
              padding: const EdgeInsets.only(top: 10),
              child: MyTab(
                tab: const ['دریافت چک', 'صدور چک'],
                value: mode,
                callback: (v) {
                  holderCtl.text = '';
                  holder.value = 0;
                  holderUID.value = '-';
                  payeeCtl.text = '';
                  payee.value = 0;
                  payeeUID.value = '-';
                  bank = 0;
                  mode.value = v;
                  toCtl.clear();
                },
              ),
            ),
          const SizedBox(height: 10),
          Obx(
            () => mode.value == 'دریافت چک'
                ? PersonInput(
                    name: 'صاحب چک',
                    fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                    controller: holderCtl,
                    require: true,
                    type: 'all',
                    onChanged: (id, uid) {
                      payeeCtl.text = '';
                      payee.value = 0;
                      bank = 0;
                      holder.value = id;
                      holderUID.value = uid;
                    },
                  )
                : Container(),
          ),
          Obx(
            () => mode.value == 'صدور چک'
                ? PersonInput(
                    name: 'گیرنده چک',
                    fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                    controller: payeeCtl,
                    require: true,
                    type: 'all',
                    onChanged: (id, uid) {
                      holderCtl.text = '';
                      holder.value = 0;
                      payee.value = id;
                      payeeUID.value = uid;
                    },
                  )
                : Container(),
          ),
          BankInput(
            name: 'بانک',
            fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
            require: true,
            controller: bankCtl,
            onChanged: (v) {
              bank = v ?? 0;
            },
          ),
          Row(
            children: [
              Flexible(
                child: Input(
                  name: 'شعبه',
                  fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                  controller: branchCtl,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Input(
                  keyboardType: TextInputType.number,
                  fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                  name: 'کد شعبه',
                  controller: branchNoCtl,
                ),
              ),
            ],
          ),
          DateInput(
            name: 'تاریخ صدور',
            fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
            require: true,
            controller: dateCtl,
            onChanged: (v) {
              if (v != null) {
                date = DateConvertor.jalaliToGrigori(v);
              }
            },
          ),
          DateInput(
            name: 'تاریخ سررسید',
            require: true,
            fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
            controller: dueDateCtl,
            onChanged: (v) {
              if (v != null) {
                dueDate = DateConvertor.jalaliToGrigori(v);
              }
            },
          ),
          Input(
            keyboardType: TextInputType.number,
            name: 'شماره چک',
            fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
            require: true,
            controller: chequeNoCtl,
          ),
          Input(
            keyboardType: TextInputType.number,
            name: 'شماره حساب',
            fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
            controller: accNoCtl,
          ),
          PriceInput(
            name: 'مبلغ چک',
            require: true,
            fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
            controller: priceCtl,
          ),
          if (type == null)
            Obx(
              () => mode.value == 'دریافت چک'
                  ? FactorCostInput(
                      name: 'بابت فاکتور فروش',
                      type: 'sell',
                      fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                      require: true,
                      rightPadding: 115,
                      controller: toCtl,
                      onChanged: (id, uid) {
                        to = id;
                        toUID = uid;
                      },
                    )
                  : Container(),
            ),
          if (type == null)
            Obx(
              () => mode.value == 'صدور چک'
                  ? FactorCostInput(
                      name: 'بابت خرید/هزینه',
                      type: 'buy,cost',
                      fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                      rightPadding: 100,
                      require: true,
                      controller: toCtl,
                      onChanged: (id, uid) {
                        to = id;
                        toUID = uid;
                      },
                    )
                  : Container(),
            ),
          Input(
            minLines: 3,
            fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
            maxLength: 3,
            name: 'شرح',
            controller: descCtl,
          ),
          if (type == null)
            Row(
              children: [
                Flexible(
                  child: BTN(
                    name: 'ثبت چک و ادامه',
                    type: BTNType.okContinue,
                    onTap: () async {
                      if (add ?? true) {
                        if (holderUID.value == '' && payeeUID.value == '') {
                          return Alert.error('طرف حساب چک را مشخص کنید.');
                        } else if (bank == null || bank == 0) {
                          return Alert.error('بانک را انتخاب کنید.');
                        } else if (date == null || date == '') {
                          return Alert.error('تاریخ صدور را مشخص کنید.');
                        } else if (dueDate == null || dueDate == '') {
                          return Alert.error('تاریخ سررسید را مشخص کنید.');
                        } else if (chequeNoCtl.text == '') {
                          return Alert.error('شماره چک را وارد کنید.');
                        } else if (priceCtl.text == '') {
                          return Alert.error('مبلغ چک را وارد کنید.');
                        } else if (toUID == null ||
                            to == null ||
                            toUID == '' ||
                            to == '') {
                          return Alert.error('بابت چک را مشخص کنید.');
                        } else {
                          var res = await ChequeFX.add(
                            bank: bank,
                            date: date,
                            dueDate: dueDate,
                            chequeNo: chequeNoCtl.text,
                            price: priceCtl.text,
                            type:
                                type ??
                                (mode.value == 'دریافت چک'
                                    ? 'sell'
                                    : toUID!.startsWith('F')
                                    ? 'buy'
                                    : 'cost'),
                            mode: mode.value,
                            holder: holder.value,
                            payee: payee.value,
                            holderUID: holderUID.value,
                            payeeUID: payeeUID.value,
                            to: to,
                            toUID: toUID,
                            accNo: accNoCtl.text,
                            branch: branchCtl.text,
                            branchNo: branchNoCtl.text,
                            desc: descCtl.text,
                            callback: (v) => callback(v),
                          );
                          if (res.toString() == 'ok') back('c');
                        }
                      } else {
                        if (holderUID.value == '' && payeeUID.value == '') {
                          Alert.error('طرف حساب چک را مشخص کنید.');
                        } else if (bank == null || bank == 0) {
                          Alert.error('بانک را انتخاب کنید.');
                        } else if (date == null || date == '') {
                          Alert.error('تاریخ صدور را مشخص کنید.');
                        } else if (dueDate == null || dueDate == '') {
                          Alert.error('تاریخ سررسید را مشخص کنید.');
                        } else if (chequeNoCtl.text == '') {
                          Alert.error('شماره چک را وارد کنید.');
                        } else if (priceCtl.text == '') {
                          Alert.error('مبلغ چک را وارد کنید.');
                        } else if (toUID == null ||
                            to == null ||
                            toUID == '' ||
                            to == '') {
                          return Alert.error('بابت چک را مشخص کنید.');
                        } else {
                          ChequeDB ch = ChequeDB(
                            id: 0,
                            uid: ID.uidNew(),
                            billID: 0,
                            billUID: '',
                            accNo: accNoCtl.text,
                            bankID: bank,
                            branch: branchCtl.text,
                            branchNo: int.tryParse(branchNoCtl.text),
                            chequeNo: chequeNoCtl.text,
                            date: date,
                            desc: descCtl.text,
                            dueDate: dueDate,
                            holder: holder.value,
                            payee: payee.value,
                            holderUID: holderUID.value,
                            payeeUID: payeeUID.value,
                            price: Price.toInt(priceCtl.text),
                            status: 0,
                            to: to,
                            toUID: toUID,
                            inserter: 0,
                            backup: 'new',
                          );
                          callback(ch);
                          back('e');
                        }
                      }
                    },
                  ),
                ),
                Flexible(
                  child: BTN(
                    name: 'انصراف',
                    type: BTNType.cancel,
                    onTap: () => back('e'),
                  ),
                ),
              ],
            ),
          BTN(
            name: item != null
                ? 'ویرایش چک'
                : (type == null)
                ? 'ثبت چک'
                : 'افزودن چک',
            type: BTNType.ok,
            onTap: () async {
              if (item == null) {
                if (add ?? true) {
                  if (holderUID.value == '' && payeeUID.value == '') {
                    Alert.error('طرف حساب چک را مشخص کنید.');
                  } else if (bank == null || bank == 0) {
                    Alert.error('بانک را انتخاب کنید.');
                  } else if (date == null || date == '') {
                    Alert.error('تاریخ صدور را مشخص کنید.');
                  } else if (dueDate == null || dueDate == '') {
                    Alert.error('تاریخ سررسید را مشخص کنید.');
                  } else if (chequeNoCtl.text == '') {
                    Alert.error('شماره چک را وارد کنید.');
                  } else if (priceCtl.text == '') {
                    Alert.error('مبلغ چک را وارد کنید.');
                  } else if (toUID == null ||
                      to == null ||
                      toUID == '' ||
                      to == '') {
                    return Alert.error('بابت چک را مشخص کنید.');
                  } else {
                    var res = await ChequeFX.add(
                      bank: bank,
                      date: date,
                      dueDate: dueDate,
                      chequeNo: chequeNoCtl.text,
                      price: priceCtl.text,
                      type:
                          type ??
                          (mode.value == 'دریافت چک'
                              ? 'sell'
                              : toUID!.startsWith('F')
                              ? 'buy'
                              : 'cost'),
                      mode: mode.value,
                      holder: holder.value,
                      payee: payee.value,
                      holderUID: holderUID.value,
                      payeeUID: payeeUID.value,
                      to: to,
                      toUID: toUID,
                      accNo: accNoCtl.text,
                      branch: branchCtl.text,
                      branchNo: branchNoCtl.text,
                      desc: descCtl.text,
                      callback: (v) => callback(v),
                    );
                    if (res.toString() == 'ok') back('e');
                  }
                } else {
                  if (holderUID.value == '' && payeeUID.value == '') {
                    Alert.error('طرف حساب چک را مشخص کنید.');
                  } else if (bank == null || bank == 0) {
                    Alert.error('بانک را انتخاب کنید.');
                  } else if (date == null || date == '') {
                    Alert.error('تاریخ صدور را مشخص کنید.');
                  } else if (dueDate == null || dueDate == '') {
                    Alert.error('تاریخ سررسید را مشخص کنید.');
                  } else if (chequeNoCtl.text == '') {
                    Alert.error('شماره چک را وارد کنید.');
                  } else if (priceCtl.text == '') {
                    Alert.error('مبلغ چک را وارد کنید.');
                  } else {
                    ChequeDB ch = ChequeDB(
                      id: 0,
                      uid: ID.uidNew(),
                      billID: 0,
                      inserter: 0,
                      billUID: '',
                      accNo: accNoCtl.text,
                      bankID: bank,
                      branch: branchCtl.text,
                      branchNo: int.tryParse(branchNoCtl.text),
                      chequeNo: chequeNoCtl.text,
                      date: date,
                      desc: descCtl.text,
                      dueDate: dueDate,
                      holder: holder.value,
                      payee: payee.value,
                      holderUID: holderUID.value,
                      payeeUID: payeeUID.value,
                      price: Price.toInt(priceCtl.text),
                      status: 0,
                      to: to,
                      toUID: toUID,
                      backup: 'new',
                    );
                    callback(ch);
                    back('e');
                    if (mode.value == 'دریافت چک' && holderUID.value != '') {
                    } else if (mode.value == 'صدور چک' &&
                        payeeUID.value != '') {}
                  }
                }
              } else {
                if (holderUID.value == '' && payeeUID.value == '') {
                  Alert.error('طرف حساب چک را مشخص کنید.');
                } else if (bank == null || bank == 0) {
                  Alert.error('بانک را انتخاب کنید.');
                } else if (date == null || date == '') {
                  Alert.error('تاریخ صدور را مشخص کنید.');
                } else if (dueDate == null || dueDate == '') {
                  Alert.error('تاریخ سررسید را مشخص کنید.');
                } else if (chequeNoCtl.text == '') {
                  Alert.error('شماره چک را وارد کنید.');
                } else if (priceCtl.text == '') {
                  Alert.error('مبلغ چک را وارد کنید.');
                } else {
                  var res = await ChequeFX.edit(
                    billIndex: billIndex,
                    chequeIndex: chequeIndex,
                    bank: bank,
                    date: date,
                    dueDate: dueDate,
                    chequeNo: chequeNoCtl.text,
                    price: priceCtl.text,
                    type: type,
                    mode: mode.value,
                    holder: holder.value,
                    payee: payee.value,
                    holderUID: holderUID.value,
                    payeeUID: payeeUID.value,
                    to: to,
                    toUID: toUID,
                    accNo: accNoCtl.text,
                    branch: branchCtl.text,
                    branchNo: branchNoCtl.text,
                    desc: descCtl.text,
                    callback: (v) => callback(v),
                  );
                  if (res.toString() == 'ok') back('e');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  init() {
    if (item != null) {
      if (item!.payeeUID == '' || item!.payeeUID == '-') {
        mode.value = 'دریافت چک';
        type = 'sell';
      } else {
        mode.value = 'صدور چک';
        type = 'sell';
      }
      for (var i = 0; i < bill.length; i++) {
        if (bill.getAt(i)!.uid == item!.billUID!) {
          billIndex = i;
          break;
        }
      }

      for (var i = 0; i < cheque.length; i++) {
        if (cheque.getAt(i)!.uid == item!.uid!) {
          chequeIndex = i;
          break;
        }
      }
      bank = item!.bankID!;
      holder.value = item!.holder!;
      payee.value = item!.payee!;
      holderUID.value = item!.holderUID!;
      payeeUID.value = item!.payeeUID!;
      date = item!.date;
      dueDate = item!.dueDate;
      to = item!.to!;
      var p = PersonFX.findByUID(item!.holderUID!);
      holderCtl.text = '${p.name} (${p.mobile})';
      payeeCtl.text = PersonFX.findByUID(item!.payeeUID!).name;
      bankCtl.text = Banks.nameByCode(item!.bankID!);
      branchCtl.text = item!.branch!;
      branchNoCtl.text = item!.branchNo!.toString();
      dateCtl.text = item!.date!.toString().toPersianDate();
      dueDateCtl.text = item!.dueDate!.toString().toPersianDate();
      chequeNoCtl.text = item!.chequeNo!;
      accNoCtl.text = item!.accNo!;
      priceCtl.text = Price.showWithCurrency(item!.price ?? 0);

      // factorFilter[i].personName +
      //     ' - فاکتور شماره ${factorFilter[i].item.id} (${factorFilter[i].item.date.toString().toPersianDate()})';
      toCtl.text = item!.to!;
      descCtl.text = item!.desc!;
    } else {
      if (type == 'buy' || type == 'cost') {
        mode.value = 'صدور چک';
        payeeCtl.text = pname!;
        payee.value = pid!;
        payeeUID.value = puid!;
      }
      if (type == 'sell') {
        holderCtl.text = pname!;
        holder.value = pid!;
        holderUID.value = puid!;
      }
    }
    return 'ok';
  }

  back(act) {
    holder = 0.obs;
    payee = 0.obs;
    date = dueDate = to = null;
    holderCtl.clear();
    payeeCtl.clear();
    bankCtl.clear();
    branchCtl.clear();
    branchNoCtl.clear();
    dateCtl.clear();
    dueDateCtl.clear();
    chequeNoCtl.clear();
    accNoCtl.clear();
    priceCtl.clear();
    toCtl.clear();
    descCtl.clear();
    if (act == 'e') Get.back();
  }
}
