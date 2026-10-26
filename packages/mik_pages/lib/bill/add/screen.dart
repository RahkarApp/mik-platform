import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/personInput.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/bill.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_utils/public/price.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:shamsi_date/shamsi_date.dart';

class BillAddScreen extends GetView {
  int? billID;
  String? mode, billUID;
  BillAddScreen({this.billID, this.billUID, required this.mode, super.key});
  RxBool isEdit = false.obs;
  final formKey = GlobalKey<FormState>();
  final dateCtl = TextEditingController();
  final priceCtl = TextEditingController();
  final personCtl = TextEditingController();
  int? indexBill;
  int? personID;
  String? personUID;
  List<BillDB>? allBill;
  BillDB? thisBill;
  double totalPay = 0;
  RxInt ctlPrice = 0.obs;
  @override
  Widget build(BuildContext context) {
    return Main(
      initState: () async => await init(),
      header: Header.page(
        context,
        text: billUID != null
            ? mode == 'credit'
                  ? 'ویرایش صورتحساب دریافت'
                  : 'ویرایش صورتحساب پرداخت'
            : 'دریافت بدون فاکتور',
      ),
      child: (d) => Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              billUID != null
                  ? Input(
                      name: mode == 'credit' ? 'پرداخت کننده' : 'دریافت کننده',
                      controller: personCtl,
                      readOnly: true,
                    )
                  : PersonInput(
                      name: mode == 'credit' ? 'پرداخت کننده' : 'دریافت کننده',
                      controller: personCtl,
                      onChanged: (id, uid) {
                        personID = id;
                        personUID = uid;
                      },
                      type: 'all',
                    ),
              PriceInput(
                name: 'مبلغ',
                desc:
                    billUID != null && allBill != null && allBill![0].to != 'ff'
                    ? 'حداکثر ${Price.showWithCurrency((allBill![0].total! - (totalPay)))}'
                    : '',
                controller: priceCtl,
                onChanged: (id) {},
              ),
              const SizedBox(height: 10),
              DateInput(name: 'تاریخ', controller: dateCtl, onChanged: (v) {}),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                BTN(
                  name: isEdit.isFalse ? 'افزودن' : 'ویرایش',
                  type: BTNType.ok,
                  onTap: () async {
                    var d = await BillFX.add(
                      jdate: dateCtl.text,
                      price: Price.toInt(priceCtl.text),
                      personId: personID ?? 0,
                      allBill: allBill,
                      totalPay: totalPay.toInt(),
                      id: billID,
                      uid: billUID,
                      indexBill: indexBill ?? 0,
                      isEdit: isEdit.value,
                      personUID: personUID!,
                    );
                    if (d == 'ok') {
                      Get.back();
                    }
                    //add('end')
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isEdit.isFalse)
                      Flexible(
                        child: BTN(
                          name: 'افزودن و ادامه',
                          type: BTNType.okContinue,
                          onTap: () async {
                            var d = await BillFX.add(
                              jdate: dateCtl.text,
                              price: Price.toInt(priceCtl.text),
                              personId: personID ?? 0,
                              personUID: personUID ?? '',
                              allBill: allBill,
                              totalPay: totalPay.toInt(),
                              id: billID,
                              uid: billUID,
                              indexBill: indexBill ?? 0,
                              isEdit: isEdit.value,
                            );
                            if (d == 'ok') {
                              priceCtl.clear();
                              personCtl.clear();
                              personID = 0;
                              personUID = null;
                            }
                          },
                        ),
                      ),
                    Flexible(
                      child: BTN(
                        name: 'انصراف',
                        type: BTNType.cancel,
                        onTap: () => Get.back(),
                      ),
                    ),
                    if (isEdit.isTrue && !BillFX.canDelete(allBill![0].toUID!))
                      Flexible(
                        child: BTN(
                          name: 'حذف',
                          type: BTNType.delete,
                          onTap: () {
                            Confirm.con(
                              context,
                              onTapConfirm: () => BillFX.delete(billUID!),
                              confirmText: 'تایید و حذف',
                              type: ConfirmType.DELETE,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  init() {
    String to = '', toUID = '';
    if (billUID != null) {
      isEdit.value = true;
      for (var i = 0; i < bill.length; i++) {
        var b = bill.getAt(i)!;
        if (b.uid == billUID) {
          thisBill = b;
          to = b.to ?? '';
          toUID = b.toUID!;
          totalPay -= b.paid!;
          priceCtl.text = Price.showWithCurrency(b.paid!);
          ctlPrice.value = b.paid!.toInt();
          personID = b.debtor! > 0 ? b.debtor : b.creditor;
          personUID = b.debtorUID! == '' || b.debtorUID! == '-'
              ? b.debtorUID
              : b.creditorUID;
          personCtl.text = b.debtorUID! != '' && b.debtorUID! != '-'
              ? PersonFX.findByUID(personUID).name +
                    ' بابت ${toUID.startsWith('F-') ? 'فاکتور' : 'هزینه'} ${to.length > 1 ? to.substring(1) : ''} بمبلغ ${Price.show(b.total ?? 0)}'
              : PersonFX.findByUID(personUID).name;

          dateCtl.text = b.date.toString().toPersianDate();
          indexBill = i;
        }
      }
      allBill = bill.values
          .where(
            (element) => element.toUID == ''
                ? element.to == to
                : element.toUID == toUID &&
                      element.creditorUID == thisBill!.creditorUID &&
                      element.debtorUID == thisBill!.debtorUID,
          )
          .toList();
      for (var b in allBill!) {
        totalPay += b.paid!;
      }
    } else {
      String? dateNow =
          "${"${Jalali.now().year}".toEnglishDigit()}/${"${Jalali.now().month}".toEnglishDigit()}/${"${Jalali.now().day}".toEnglishDigit()}";
      dateCtl.text = dateNow;
      priceCtl.clear();
      personCtl.clear();
    }
    return '';
  }
}
