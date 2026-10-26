import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_pages/cost/remote_screen.dart';
// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/CatInput.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/factorCostInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/personInput.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_data/utils/fx/cost.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_utils/public/price.dart';

import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:mik_consts/colors.dart';


class CostAddScreen extends GetView {
  var item;
  int? pid;
  String? puid;
  CostAddScreen({this.item, required this.puid, this.pid, super.key});
  RxBool isEdit = false.obs, cash = true.obs;
  RxInt notPaid = 0.obs;

  final categoryCtl = TextEditingController();
  final nameCtl = TextEditingController();
  final priceCtl = TextEditingController();
  final personCtl = TextEditingController();
  int personID = 0;
  String personUID = '';
  RxString categtyUID = ''.obs;
  final factorCtl = TextEditingController();
  String factorUID = '';
  final descriptionCtl = TextEditingController();
  final dateCtl = TextEditingController();
  final paidCtl = TextEditingController();
  final deadLineCtl = TextEditingController();
  var allBill;
  var otherPay = 0.0;
  @override
  Widget build(BuildContext context) {
    if (BusinessContext.forApp('mik') != null) {
      if (item != null) {
        return Main(initState: () async { Alert.error('این رکورد قدیمی شناسه هزینه سرور ندارد. از فهرست هزینه‌ها رکورد سرور را انتخاب کنید.'); return ''; }, header: Header.page(context, text: ''), child: (_) => const Text('این رکورد قدیمی شناسه هزینه سرور ندارد. از فهرست هزینه‌ها رکورد سرور را انتخاب کنید.'));
      }
      return const RemoteExpenseForm(appId: 'mik');
    }
    return Main(
      initState: () async => await init(),
      header: Header.page(context, text: item != null ? 'ویرایش هزینه' : 'هزینه جدید'),
      child: (d) => SingleChildScrollView(
        child: Column(
          children: [
            Input(name: 'عنوان هزینه', require: true, controller: nameCtl),
            Obx(
              () => CatInput(
                name: 'دسته‌بندی',
                type: 'cost',
                selected: [categtyUID.value],
                require: true,
                onChanged: (v) {
                  try {
                    categtyUID.value = v['uid'];
                    categoryCtl.text = v['name'] ?? '';
                  } catch (e) {
                    categtyUID.value = '';
                    categoryCtl.text = '';
                  }
                },
                controller: categoryCtl,
              ),
            ),
            PriceInput(
              name: 'مبلغ',
              require: true,
              controller: priceCtl,
              onChanged: (v) {
                if (item != null && allBill[0].total == allBill[0].paid) {
                  paidCtl.text = v;
                }
                notPaidPrice();
              },
            ),
            PersonInput(
              name: 'ارتباط با فرد',
              require: true,
              controller: personCtl,
              onChanged: (id, uid) {
                personID = id;
                personUID = uid;
              },
              type: 'all',
            ),
            FactorCostInput(
              name: 'ارتباط با فاکتور',
              // desc: 'برای گزارش گیری، بهتر است وارد کنید',
              controller: factorCtl,
              type: 'sell,buy',
              onChanged: (id, uid) {
                factorUID = uid;
              },
            ),
            Input(name: 'توضیحات', minLines: 2, maxLines: 2, controller: descriptionCtl),
            DateInput(name: 'تاریخ', require: true, controller: dateCtl, onChanged: (v) {}),
            const SizedBox(height: 20),
            Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => {
                      if (item == null || (item != null && !(allBill[0].total! > allBill[0].paid!)))
                        {cash.value = true}
                      else
                        Alert.error('امکان تغییر به پرداخت شده وجود ندارد.\nجهت تسویه این هزینه از قسمت صورت‌حساب‌ها اقدام نمایید.'),
                    },
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
                    child: Container(
                      width: Get.width / 3,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: cash.isTrue ? AppColors.secondary : Colors.transparent,
                        border: Border.all(color: cash.isTrue ? AppColors.secondary : Colors.grey),
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'نقدی',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cash.isTrue ? Colors.white : Colors.grey),
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                    onTap: () => {cash.value = false},
                    child: Container(
                      width: Get.width / 3,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        border: Border.all(color: cash.isFalse ? AppColors.secondary : Colors.grey),
                        color: cash.isFalse ? AppColors.secondary : Colors.transparent,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'اقساطی',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cash.isFalse ? Colors.white : Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Obx(
              () => cash.isFalse
                  ? Column(
                      children: [
                        PriceInput(
                          name: 'پرداخت نقدی اولیه',
                          onChanged: (v) {
                            notPaidPrice();
                          },
                          rightPadding: 100,
                          controller: paidCtl,
                        ),
                        if (otherPay > 0)
                          Container(
                            padding: const EdgeInsets.only(right: 20, left: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    InkWell(onTap: () => showOtherPay(context), child: const Icon(IconsaxPlusLinear.info_circle, size: 13)),
                                    const Text(' پرداخت از صورتحساب: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  ],
                                ),
                                Text(Price.showWithCurrency(otherPay), style: const TextStyle(fontSize: 20)),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.only(right: 20, left: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('مانده: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                              Obx(() => Text(Price.showWithCurrency(notPaid.value - otherPay.toInt()), style: const TextStyle(fontSize: 20))),
                            ],
                          ),
                        ),
                        DateInput(name: 'مهلت پرداخت', controller: deadLineCtl, onChanged: (v) {}),
                      ],
                    )
                  : Container(),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  BTN(
                    name: isEdit.isFalse ? 'افزودن' : 'ویرایش',
                    type: BTNType.ok,
                    onTap: () async {
                      var d = await CostFX.add(
                        item: item,
                        allBill: allBill,
                        name: nameCtl.text,
                        jdate: dateCtl.text,
                        catUID: categtyUID.value,
                        price: priceCtl.text,
                        person: personCtl.text,
                        personUID: personUID,
                        personID: personID,
                        paid: paidCtl.text,
                        cash: cash.value,
                        isEdit: isEdit.value,
                        notPaid: notPaid.value,
                        otherPay: otherPay.toInt(),
                        factorUID: factorUID,
                        deadLine: deadLineCtl.text,
                        description: descriptionCtl.text,
                      );

                      if (d != null) {
                        Get.back(result: d);
                      }
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
                              var d = await CostFX.add(
                                item: item,
                                allBill: allBill,
                                name: nameCtl.text,
                                jdate: dateCtl.text,
                                catUID: categtyUID.value,
                                price: priceCtl.text,
                                person: personCtl.text,
                                personID: personID,
                                personUID: personUID,
                                paid: paidCtl.text,
                                cash: cash.value,
                                isEdit: isEdit.value,
                                notPaid: notPaid.value,
                                otherPay: otherPay.toInt(),
                                factorUID: factorUID,
                                deadLine: deadLineCtl.text,
                                description: descriptionCtl.text,
                              );
                              // if (d.toString() == 'ok') {
                              nameCtl.clear();
                              categoryCtl.clear();
                              categtyUID.value = '';
                              priceCtl.clear();
                              factorCtl.clear();
                              factorUID = '';
                              personCtl.clear();
                              personID = 0;
                              personUID = '';
                              paidCtl.clear();
                              deadLineCtl.text = "${"${Jalali.now().year}".toEnglishDigit()}/${"${Jalali.now().month}".toEnglishDigit()}/${"${Jalali.now().day}".toEnglishDigit()}";
                              descriptionCtl.clear();
                              //    }
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
            ),
          ],
        ),
      ),
    );
  }

  init() {
    if (pid != null) {
      personID = pid!;
      personUID = puid!;
      var pr = PersonFX.findByUID(puid);
      personCtl.text = pr.isAdmin ? pr.name + " (مدیر)" : pr.name + ' (${pr.mobile})';
    }
    if (item != null) {
      otherPay = 0.0;
      nameCtl.text = item.name;
      categtyUID.value = item.categoryUID;
      var cc = costCategory.values.where((element) => element.uid == item.categoryUID).toList();
      categoryCtl.text = cc.isNotEmpty ? cc[0].name! : '';
      priceCtl.text = Price.showWithCurrency(item.price);
      personID = item.personID;
      personUID = item.personUID;
      var pr = PersonFX.findByUID(item.personUID);
      personCtl.text = pr.isAdmin ?? false ? pr.name + " (مدیر)" : pr.name + ' (${pr.mobile})';
      if (item.factorUID != null && item.factorUID != '' && item.factorUID != '-') {
        var f = InvoiceFX.find(item.factorUID.toString().substring(2));
        if (f != null) {
          factorUID = item.factorUID;
          factorCtl.text = PersonFX.findByUID(f.personUID).name + ' - فاکتور شماره ${f.id} (${f.date.toString().toPersianDate()})';
        }
      }
      descriptionCtl.text = item.description;
      dateCtl.text = item.date.toString().toPersianDate();
      isEdit = true.obs;
      allBill = bill.values.where((element) => item.billUID.contains(element.uid)).toList();
      allBill!.forEach((element) {
        otherPay += element.paid;
      });
      otherPay -= allBill[0].paid;
      paidCtl.text = Price.showWithCurrency(allBill[0].paid);
      try {
        deadLineCtl.text = allBill[0].deadLine!.toString().toPersianDate();
        // ignore: empty_catches
      } catch (e) {}
      cash.value = !(allBill[0].total! > allBill[0].paid!);
      notPaidPrice();
    } else {
      String? dateNow = "${"${Jalali.now().year}".toEnglishDigit()}/${"${Jalali.now().month}".toEnglishDigit()}/${"${Jalali.now().day}".toEnglishDigit()}";
      dateCtl.text = dateNow;
      deadLineCtl.text = dateNow;
    }
    return '';
  }

  notPaidPrice() {
    if (paidCtl.text.isNotEmpty) {
      notPaid.value = (Price.toInt(priceCtl.text) - Price.toInt(paidCtl.text));
    } else {
      notPaid.value = Price.toInt(priceCtl.text);
    }
  }

  showOtherPay(context) {
    MyBottomSheet.view(
      context,
      child: (scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Column(
          children: [
            for (var i = 0; i < allBill!.length; i++)
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(allBill![i].date.toString().toPersianDate()), if (i == 0) const Text('پرداخت اولیه'), Text(Price.showWithCurrency(allBill![i].paid.toStringAsFixed(0)))],
                  ),
                  MyDivider(),
                ],
              ),
            const Text('برای ویرایش پرداختی ها از بخش صورت‌حساب‌ها اقدام نمایید.', textAlign: TextAlign.justify),
          ],
        ),
      ),
      title: 'لیست پرداخت‌های این هزینه',
    );
  }
}
