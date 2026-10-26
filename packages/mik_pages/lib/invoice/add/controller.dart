import 'package:mik_variables/permissions.dart';
// ignore_for_file: invalid_use_of_protected_member, unrelated_type_equality_checks

import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/input/dateInput.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/numInput.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_components/elements/scanner.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/acc.dart';
import 'package:mik_data/utils/fx/branch.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_pages/cheque/components/form.dart';
import 'package:mik_pages/invoice/add/components/model.dart';
import 'package:mik_utils/public/POS/mikyarpos.dart';
import 'package:mik_utils/public/POS/pos.dart';
import 'package:mik_utils/public/banks.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';

import 'package:persian_number_utility/persian_number_utility.dart';

class InvoiceAddScreenController extends GetxController {
  String? type;
  InvoiceDB? item;
  String? puid;
  final RxBool myChange = false.obs;

  bool? isTabBar = true;

  InvoiceAddScreenController({
    //required
    this.type,
    this.item,
    this.puid,
    this.isTabBar,
  });
  ScrollController scrollController = ScrollController();
  TextEditingController personCtl = TextEditingController();
  TextEditingController paidCtl = TextEditingController();
  TextEditingController discountCtl = TextEditingController();
  TextEditingController excessCtl = TextEditingController();
  TextEditingController marketerCtl = TextEditingController();
  int marketerID = 0;
  TextEditingController commissionCtl = TextEditingController();
  TextEditingController descCtl = TextEditingController();
  TextEditingController dateCtl = TextEditingController(
    text: DateConvertor.jalaliNow(),
  );
  FocusNode personF = FocusNode();
  TextEditingController deadLineCtl = TextEditingController();
  TextEditingController docCtl = TextEditingController();
  TextEditingController shippingCostCtl = TextEditingController();
  TextEditingController shippingCompanyCtl = TextEditingController();
  TextEditingController shippingTrackingCtl = TextEditingController();
  TextEditingController branchCtl = TextEditingController();
  RxString branchUID = ''.obs;
  RxInt personId = 0.obs;
  RxString personUID = ''.obs;
  String marketerUID = '';
  RxList<InvoiceItemModel> productSelected = <InvoiceItemModel>[].obs;
  RxBool productSelectedCahnge = false.obs;
  RxList<String> payTab = <String>[].obs;
  RxString payTabSelect = ''.obs;
  List<BillDB> allBill = [];
  var otherPay = 0.0;
  RxString cash = ''.obs;
  RxInt totalPrice = 0.obs;
  RxInt notPaid = 0.obs;
  RxList<ChequeDB> chequeList = <ChequeDB>[].obs;
  RxBool change = false.obs, commissionChange = false.obs;
  RxString typeMode = ''.obs;
  RxString rxtype = ''.obs;
  List<String> tabs = ['فروش', 'خرید'];
  RxBool activeBranch = false.obs;
  bool isEdit = false;

  addNew() {
    priceFind();
    notPaidPrice();
    if (rxtype.value != 'buy') commissionFind();
  }

  confirmForLowPrice(context) {
    MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        spacing: 15,
        children: [
          Text(
            'فروش با قیمت کمتر را تایید میکنید؟',
            style: TextStyle(fontSize: 16),
          ),
          Row(
            children: [
              Flexible(
                child: BTN(
                  onTap: () {
                    Get.back();
                    step2(context);
                  },
                  name: 'تایید و ادامه',
                ),
              ),
              Flexible(
                child: BTN(
                  onTap: () {
                    Get.back();
                  },
                  type: BTNType.cancel,
                  name: 'اصلاح',
                ),
              ),
            ],
          ),
        ],
      ),
      // h: 100,
      title: 'قیمت فروش از قیمت خرید کمتر است!',
    );
  }

  step2(context) async {
    List p = [];
    List w = [];
    if (rxtype.value == 'buy') AccountingFX.balance();
    for (var i = 0; i < productSelected.length; i++) {
      var e = productSelected[i];
      for (var j = 0; j < e.pro.length; j++) {
        p.add(rxtype.value == 'buy' ? e.pro[j].price : e.pro[j].price);
        if (e.type != 'service') w.add(e.pro[j].warehouseUID);
      }
    }
    if (personCtl.text.isEmpty) {
      return Alert.warning(
        rxtype.value == 'sell'
            ? 'مشتری را انتخاب کنید.'
            : 'تامین‌کننده را انتخاب کنید',
      );
    } else if (productSelected.isEmpty) {
      return Alert.warning('هیچ محصولی انتخاب نشده!');
    } else if (p.contains(0)) {
      return Alert.warning(
        'قیمت محصولات را بررسی کنید!\nقیمت نمیتواند صفر باشد!!!',
      );
    } else if (w.contains('') && rxtype.value != 'pf') {
      return Alert.warning('انبار تمام محصولات را انتخاب کنید.');
    } else {
      MyBottomSheet.view(
        context,
        child: (scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Column(
            children: [
              if (PermissionAccess.hasPermission(PermissionsName.invoicesSellDiscountApply))
                PriceInput(
                  controller: discountCtl,
                  name: 'تخفیف',
                  fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                  onChanged: (v) {
                    priceFind();
                  },
                ),
              if (PermissionAccess.hasPermission(PermissionsName.invoicesSellChargesApply))
                PriceInput(
                  controller: excessCtl,
                  rightPadding: 110,
                  fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                  name: rxtype.value == 'buy'
                      ? 'هزینه اضافی پرداختی'
                      : 'هزینه اضافی دریافتی',
                  onChanged: (v) {
                    priceFind();
                  },
                ),
              // if (rxtype.value != 'buy')
              //   PersonInput(
              //       controller: marketerCtl,
              //       type: 'marketer',
              //       fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
              //       onChanged: (id, uid) {
              //         marketerID = id;
              //         marketerUID = uid;
              //       },
              //       name: 'بازاریاب'),
              if (rxtype.value != 'buy')
                PriceInput(
                  controller: commissionCtl,
                  fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                  name: 'کمیسیون',
                ),
              Input(
                controller: descCtl,
                name: 'توضیحات',
                fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                maxLines: 2,
                minLines: 2,
              ),
              NumberInput(
                controller: docCtl,
                fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                name: 'شماره سند',
              ),
              DateInput(
                controller: dateCtl,
                onChanged: (v) {},
                require: true,
                fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                name: 'تاریخ سفارش',
              ),
              if (item != null && rxtype.value == 'sell')
                Column(
                  children: [
                    const SizedBox(height: 10),
                    MyDivider(text: 'اطلاعات ارسال سفارش'),
                    PriceInput(
                      controller: shippingCostCtl,
                      fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                      name: 'هزینه پرداختی بابت ارسال',
                    ),
                    Input(
                      controller: shippingCompanyCtl,
                      fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                      name: 'شرکت ارسال کننده',
                    ),
                    Input(
                      controller: shippingTrackingCtl,
                      fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
                      name: 'کدرهگیری',
                    ),
                  ],
                ),
              if ((item == null || item != null && rxtype.value == 'convert') &&
                  personCtl.text != 'اول دوره')
                Column(
                  children: [
                    MyDivider(text: 'تسویه و پرداخت فاکتور'),
                    Container(
                      padding: const EdgeInsets.only(right: 20, left: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'مبلغ کل: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Obx(
                            () => Text(
                              Price.showWithCurrency(totalPrice.value),
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rxtype.value != 'pf')
                      MyTab(
                        width: Responsive.isMobile(context),
                        widthSize: 100,
                        tab: payTab,
                        value: payTabSelect,
                        callback: (c) => payTabHandle(c),
                      ),
                    const SizedBox(height: 10),
                    if (item == null ||
                        (item != null && rxtype.value == 'convert'))
                      Obx(
                        () => cash.value == 'credit'
                            ? creadtiPay(context)
                            : Container(),
                      ),
                  ],
                ),
              if (item != null && rxtype.value != 'convert')
                Container(
                  padding: const EdgeInsets.only(top: 5, bottom: 8),
                  child: const Text(
                    'وضعیت تسویه و پرداخت فاکتور از جزئیات فاکتور بررسی و ویرایش کنید.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (rxtype.value == 'buy')
                      Flexible(
                        child: MyDivider(
                          text: 'موجودی نقدی: ',
                          entText: Price.showWithCurrency(
                            balanceMony['tBalance'],
                          ).split('.')[0],
                          endIndent: 5,
                        ),
                      ),
                  ],
                ),
              ),
              BTN(
                // wait: waitServer.value,
                onTap: () async {
                  Map? metaData;
                  if (payTabSelect.value == 'کارتخوان') {
                    late var response;
                    if (kDebugMode) {
                      response = {
                        "amount": "3500000",
                        "responseDescription": "تراکنش موفق",
                        "responseTime": "112910",
                        "retrievalReferencedNumber": 1,
                        "sessionId": "fd101acc-39c3-57f0-a788-77c8f07dac71",
                        "terminalID": "نسخه تستی",
                        "versionName": "2.0.0",
                        "maskedCardNumber": "621986******9993",
                        "referenceID": "602287752558",
                        "responseDate": "260526",
                        "responseCode": "000",
                      };
                    } else {
                      response = await MikYarPOS.pay(totalPrice.value * 10);
                    }

                    print('rrrr: ${response}');
                    if (POSFX.isCardOK(response)) {
                      print('ok PAY');
                      metaData = await MikYarPOS.getMetaData(response);
                      print('metadata is $metaData');
                      var res = await InvoiceFX.addNew(
                        invoiceUID: item?.uid,
                        branchUID: branchUID.value,
                        date: DateConvertor.jalaliToGrigori(dateCtl.text),
                        personID: personId.value,
                        personUID: personUID.value,
                        type: rxtype.value,
                        cash: cash.value,
                        notPaid: notPaid.value,
                        otherPay: otherPay,
                        deadLineDate: DateConvertor.jalaliToGrigori(
                          deadLineCtl.text,
                        ),
                        allBill: allBill,
                        tPrice: totalPrice.value,
                        paidPrice: Price.toInt(paidCtl.text),
                        chequeList: chequeList.value,
                        items: productSelected,
                        doc: docCtl.text,
                        excess: Price.toInt(excessCtl.text),
                        discount: Price.toInt(discountCtl.text),
                        shippingCost: Price.toInt(shippingCostCtl.text),
                        shippingCompany: shippingCompanyCtl.text,
                        status: rxtype.value == 'buy'
                            ? null
                            : rxtype.value == 'convert'
                            ? 1
                            : item != null
                            ? null
                            : rxtype.value != 'pf'
                            ? 1
                            : 900,
                        commission: Price.toInt(commissionCtl.text),
                        cRecipient: marketerID,
                        cRecipientUID: marketerUID,
                        cStatus: 0,
                        statusDate: DateConvertor.jalaliToGrigori(dateCtl.text),
                        editDate: item != null && rxtype.value != 'convert'
                            ? DateTime.now().toIso8601String()
                            : null,
                        description: descCtl.text,
                        meta: metaData,
                        trakingCode: shippingTrackingCtl.text,
                      );
                    }
                  } else {
                    var res = await InvoiceFX.addNew(
                      invoiceUID: item?.uid,
                      branchUID: branchUID.value,
                      date: DateConvertor.jalaliToGrigori(dateCtl.text),
                      personID: personId.value,
                      personUID: personUID.value,
                      type: rxtype.value,
                      cash: cash.value,
                      notPaid: notPaid.value,
                      otherPay: otherPay,
                      deadLineDate: DateConvertor.jalaliToGrigori(
                        deadLineCtl.text,
                      ),
                      allBill: allBill,
                      tPrice: totalPrice.value,
                      paidPrice: Price.toInt(paidCtl.text),
                      chequeList: chequeList.value,
                      items: productSelected,
                      doc: docCtl.text,
                      excess: Price.toInt(excessCtl.text),
                      discount: Price.toInt(discountCtl.text),
                      shippingCost: Price.toInt(shippingCostCtl.text),
                      shippingCompany: shippingCompanyCtl.text,
                      status: rxtype.value == 'buy'
                          ? null
                          : rxtype.value == 'convert'
                          ? 1
                          : item != null
                          ? null
                          : rxtype.value != 'pf'
                          ? 1
                          : 900,
                      commission: Price.toInt(commissionCtl.text),
                      cRecipient: marketerID,
                      cRecipientUID: marketerUID,
                      cStatus: 0,
                      statusDate: DateConvertor.jalaliToGrigori(dateCtl.text),
                      editDate: item != null && rxtype.value != 'convert'
                          ? DateTime.now().toIso8601String()
                          : null,
                      description: descCtl.text,
                      meta: metaData,
                      trakingCode: shippingTrackingCtl.text,
                    );
                  }

                  // if (res == 'ok') {
                  //   Get.back();
                  //   Get.back(result: 'ok');
                  //   Alert.success('فاکتور با موفقیت ثبت شد.');
                  // }
                },
                name: item == null ? 'ثبت فاکتور' : 'ویرایش فاکتور',
              ),
            ],
          ),
        ),
        //scrollController: scrollController,
        //showClose: false,
        title: 'تکمیل فاکتور',
        height: 450,
        width: 400,
        // initialChildSize: isEdit ? 0.85 : 0.7
        // h: Get.height * 0.65
      ); //rxtype.value != 'buy' ? 585 : 540);
    }
  }

  commissionFind() {
    List<String> productuid = productSelected.map((e) => e.uid).toList();
    List<int> prices = []; //productSelected.map((e) => e.price).toList();
    List<double> amounts = []; // productSelected.map((e) => e.amount).toList();
    num cmsn = InvoiceFX.findCommission(
      items: productSelected,
      tPrice: totalPrice.value,
      discount: discountCtl.text.isNotEmpty ? Price.toInt(discountCtl.text) : 0,
    );
    commissionCtl.text = Price.showWithCurrency(cmsn);
    commissionChange.toggle();
  }

  priceFind() {
    int discount = discountCtl.text.isNotEmpty
        ? Price.toInt(discountCtl.text)
        : 0;
    int excess = excessCtl.text.isNotEmpty ? Price.toInt(excessCtl.text) : 0;
    int price = 0;
    for (var i = 0; i < productSelected.length; i++) {
      for (var element in productSelected[i].pro) {
        price += int.parse((element.amount * element.price).toStringAsFixed(0));
      }
    }
    totalPrice.value = price + excess - discount;
    if (paidCtl.text.isEmpty) notPaid.value = totalPrice.value;
  }

  notPaidPrice() {
    if (paidCtl.text.isNotEmpty) {
      notPaid.value =
          (totalPrice.value - Price.toInt(paidCtl.text)).toInt() -
          otherPay.toInt();
    } else {
      notPaid.value = totalPrice.value - otherPay.toInt();
    }
    for (var i = 0; i < chequeList.length; i++) {
      notPaid.value -= chequeList[i].price!;
    }
  }

  showOtherPay(context) {
    MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        children: [
          Container(
            constraints: BoxConstraints(
              maxHeight: Get.height * 0.6,
              minHeight: 0,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  for (var i = 0; i < allBill.length; i++)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(allBill[i].date.toString().toPersianDate()),
                            //if (i == 0) Text('پرداخت اولیه'),
                            // if (i > 0)
                            Text(
                              i == 0 &&
                                      allBill[i].type == 'credit' &&
                                      allBill[i].paid! > 0
                                  ? 'نقدی'
                                  : allBill[i].type == 'credit'
                                  ? 'اقساطی'
                                  : allBill[i].type == 'online'
                                  ? 'آنلاین'
                                  : allBill[i].type == 'smart'
                                  ? 'لینک‌هوشمند'
                                  : allBill[i].type == 'cheque'
                                  ? 'چک'
                                  : 'نقد',
                              style: const TextStyle(color: Colors.grey),
                              textAlign: TextAlign.end,
                            ),
                            Text(Price.showWithCurrency(allBill[i].paid!)),
                          ],
                        ),
                        MyDivider(),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const Text(
            'برای ویرایش پرداختی ها از بخش صورت‌حساب‌ها اقدام نمایید.',
            textAlign: TextAlign.justify,
          ),
        ],
      ),
      title: 'لیست پرداخت‌های این فاکتور',
    );
  }

  creadtiPay(context) {
    return Column(
      children: [
        PriceInput(
          name: 'پرداخت نقدی اولیه',
          fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
          rightPadding: 110,
          onChanged: (v) {
            notPaidPrice();
          },
          controller: paidCtl,
        ),
        Obx(
          () => Column(
            children: [
              for (int i = 0; i < chequeList.length; i++)
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.only(
                        right: 10,
                        left: 10,
                        top: 6,
                        bottom: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            height: 30,
                            padding: const EdgeInsets.only(left: 10),
                            child: Image.asset(
                              Banks.logoByCode(chequeList[i].bankID!),
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              'چک ${Banks.nameByCode(chequeList[i].bankID)}',
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              Price.showWithCurrency(chequeList[i].price!),
                            ),
                          ),
                          Text(
                            chequeList[i].dueDate.toString().toPersianDate(),
                          ),
                          InkWell(
                            onTap: () {
                              Confirm.con(
                                context,
                                onTapConfirm: () {
                                  chequeList.removeAt(i);
                                  notPaidPrice();
                                  change.toggle();
                                  Get.back();
                                },
                                confirmText: 'تایید و حذف',
                                type: ConfirmType.DELETE,
                              );
                            },
                            child: Container(
                              width: 40,
                              alignment: Alignment.centerLeft,
                              child: const Icon(
                                IconsaxPlusLinear.trash_square,
                                size: 25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    EndLine(show: i + 1 < chequeList.length, rightPadding: 40),
                  ],
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 10, left: 5, bottom: 5),
          child: Row(
            children: [
              Flexible(flex: 2, child: Container()),
              Flexible(
                child: BTN(
                  name: 'افزودن چک',
                  icon: IconsaxPlusLinear.money_4,
                  textColor: Colors.white,
                  onTap: () {
                    if (personId.value == null) {
                      return Alert.info(
                        rxtype.value == 'buy'
                            ? 'تامین‌کننده را انتخاب کنید'
                            : 'خریدار را انتخاب کنید',
                      );
                    } else if (productSelected == null ||
                        (productSelected != null && productSelected.isEmpty)) {
                      return Alert.info('ابتدا محصولات را انتخاب کنید.');
                    } else {
                      MyBottomSheet.view(
                        context,
                        child: (scrollController) => ChequeAddForm(
                          type: rxtype.value,
                          pid: personId.value,
                          puid: personUID.value,
                          pname: personCtl.text,
                          add: false,
                          callback: (c) {
                            chequeList.add(c);
                            notPaidPrice();
                            change.toggle();
                          },
                        ),
                        title: 'افزودن چک',
                        //h: 500
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        if (otherPay > 0)
          Container(
            padding: const EdgeInsets.only(right: 20, left: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => showOtherPay(context),
                      child: const Icon(
                        IconsaxPlusLinear.info_circle,
                        size: 13,
                      ),
                    ),
                    const Text(
                      ' پرداخت از صورتحساب: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  Price.showWithCurrency(otherPay.toInt()),
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.only(right: 20, left: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'مانده: ',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              Obx(
                () => Text(
                  Price.showWithCurrency(notPaid.value),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
        ),
        DateInput(
          name: 'مهلت تسویه',
          onChanged: (v) {},
          fillColor: darkMode.isFalse ? Colors.grey.shade300 : null,
          controller: deadLineCtl,
        ),
      ],
    );
  }

  payTabHandle(c) {
    switch (c) {
      case 'نقدی':
        if (rxtype.value == 'convert' ||
            item == null ||
            (item != null && !(allBill[0].total! > allBill[0].paid!))) {
          cash.value = 'paid';
          payTabSelect.value = 'نقدی';
        } else {
          Alert.error(
            'امکان تغییر به پرداخت شده وجود ندارد.\nجهت تسویه این فاکتور از قسمت صورت‌حساب‌ها اقدام نمایید.',
          );
        }
        break;
      case 'کارتخوان':
        payTabSelect.value = 'کارتخوان';
        cash.value = 'pos';
        break;
      case 'آنلاین':
        payTabSelect.value = 'آنلاین';
        cash.value = 'online';
        break;
      case 'اقساطی':
        payTabSelect.value = 'اقساطی';
        cash.value = 'credit';
        try {
          // scrollController.animateTo(625,
          //     // scrollController
          //     //     .position.maxScrollExtent,
          //     duration: const Duration(milliseconds: 200),
          //     curve: Curves.easeInOut);
        } catch (e) {}
        break;
      default:
    }
  }

  barcodeScan(context, {warehouseID}) async {
    String? cameraScanResult = await Scanner.barcode(context);
    int? exist;
    ProductDB? pr;
    if (cameraScanResult == null ||
        cameraScanResult == ' ' ||
        cameraScanResult == '' ||
        cameraScanResult == '-1') {
    } else if (cameraScanResult != null &&
        cameraScanResult != ' ' &&
        cameraScanResult != '' &&
        cameraScanResult != '-1') {
      for (var i = 0; i < product.length; i++) {
        ProductDB temp = product.getAt(i)!;
        if (temp.barcode == cameraScanResult) {
          pr = temp;
          break;
        }
      }

      if (pr != null) {
        String prouid = '-';
        List<ProductProDB> pp = productPro.values
            .where((o) => o.productUID == pr!.uid)
            .toList();
        if (pp.isNotEmpty) {
          await MyBottomSheet.viewAsync(
            Column(
              children: [
                ...pp.map(
                  (p) => Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 3,
                          horizontal: 15,
                        ),
                        child: InkWell(
                          onTap: () {
                            prouid = p.uid!;
                            Get.back();
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                pr!.name ?? '',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ProductFX.productProNameWidget(p.property),
                            ],
                          ),
                        ),
                      ),
                      EndLine(),
                    ],
                  ),
                ),
              ],
            ),
            header: 'انتخاب تنوع محصولی',
          );
        }
        if (pp.isNotEmpty && prouid == '-') {
          // Alert.success('کالای ${pr.name} افزوده شد.');
          return;
        }
        print(
          rxtype.value == 'buy' ||
              rxtype.value == 'pf' ||
              (warehouseID == null &&
                  ProductFX.productInAllWarehouse(pr.uid!, prouid: prouid) > 0),
        );
        print(
          (warehouseID != null &&
              ProductFX.productInWarehouse(pr.uid!, prouid, warehouseID) > 0),
        );
        if ((warehouseID == null &&
                ProductFX.productInAllWarehouse(pr.uid!, prouid: prouid) > 0) ||
            (warehouseID != null &&
                ProductFX.productInWarehouse(pr.uid!, prouid, warehouseID) >
                    0)) {
          int prc = ProductFX.findPrice(pr.uid!, prouid: prouid);
          int bprc = ProductFX.lastBuyPrice(pr.uid!, prouid);
          int prIndex = productSelected.indexWhere((p) => p.uid == pr!.uid);

          if (prIndex > -1) {
            int proIndex = productSelected[prIndex].pro.indexWhere(
              (o) => o.uid == prouid,
            );
            if (proIndex > -1) {
              productSelected[prIndex].pro[proIndex].amount++;
            } else {
              productSelected[prIndex].pro.add(
                InvoiceProItemModel(
                  uid: prouid,
                  amount: 1,
                  price: prc,
                  buyPrice: bprc,
                  warehouseUID: warehouseID ?? '',
                  parameters: [],
                ),
              );
            }
          } else {
            productSelected.add(
              InvoiceItemModel(
                id: pr.id!,
                uid: pr.uid!,
                name: pr.name!,
                type: pr.type!,
                barcode: pr.barcode ?? '',
                pro: [
                  InvoiceProItemModel(
                    uid: prouid,
                    amount: 1.0,
                    price: prc,
                    buyPrice: bprc,
                    warehouseUID: warehouseID ?? '',
                    parameters: [],
                  ),
                ],
              ),
            );
          }
          Alert.success('کالای ${pr.name} افزوده شد.');
          // addNew();
          productSelectedCahnge.toggle();
        } else {
          Alert.error('کالای مورد نظر موجود نیست!');
        }
      } else {
        Alert.error('کالای مورد نظر موجود نیست!');
      }
    } else {
      Alert.error('کالایی با بارکد $cameraScanResult یافت نشد.');
    }
  }

  init({initVar = true}) {
    if (initVar) {
      scrollController = ScrollController();
      personCtl = TextEditingController();
      paidCtl = TextEditingController();
      discountCtl = TextEditingController();
      excessCtl = TextEditingController();
      marketerCtl = TextEditingController();
      // int marketerID = 0;
      commissionCtl = TextEditingController();
      descCtl = TextEditingController();
      dateCtl = TextEditingController(text: DateConvertor.jalaliNow());
      personF = FocusNode();
      deadLineCtl = TextEditingController();
      docCtl = TextEditingController();
      shippingCostCtl = TextEditingController();
      shippingCompanyCtl = TextEditingController();
      shippingTrackingCtl = TextEditingController();
      branchCtl = TextEditingController();
      personId = 0.obs;
      personUID = ''.obs;
      marketerUID = '';
      productSelected = <InvoiceItemModel>[].obs;
      payTab = <String>[].obs;
      payTabSelect = ''.obs;
      allBill = [];
      otherPay = 0.0;
      cash = ''.obs;
      totalPrice = 0.obs;
      notPaid = 0.obs;
      chequeList = <ChequeDB>[].obs;
      change.value = false;
      commissionChange = false.obs;

      tabs = ['فروش', 'خرید'];

      branchUID.value = '';
    }

    // if (branchs.length == 1) {
    //   branchCtl.text = branch.values
    //           .where((element) => element.uid == branchs[0])
    //           .first
    //           .active!
    //       ? branch.values
    //           .where((element) => element.uid == branchs[0])
    //           .first
    //           .name
    //       : '';
    //   branchUID.value = branchs[0];
    // }

    if (branchs.isNotEmpty) {
      branch.values.forEach((b) {
        if (branchs.contains(b.uid)) {
          if (b.active!) {
            activeBranch.value = true;
            return;
          }
        }
      });
    }
    payTab.value = [];

    if (InvoiceFX.toType(typeMode.value) == 'sell' && POSFX.isPos()) {
      payTab.add('کارتخوان');
    }

    if (InvoiceFX.toType(typeMode.value) != 'pf' &&
        (PermissionAccess.hasPermission(PermissionsName.invoicesSellPaymentReceive) || PermissionAccess.hasPermission(PermissionsName.invoicesBuyPaymentPay))) {
      payTab.add('نقدی');
    }

    // bool isPos = await POSFX.isPos();

    // if (InvoiceFX.toType(typeMode.value) == 'sell' && isPos) {
    //   payTab.add('POS');
    // }

    if (InvoiceFX.toType(typeMode.value) != 'pf' &&
        InvoiceFX.toType(typeMode.value) == 'sell' &&
        PermissionAccess.hasPermission(PermissionsName.invoicesSellPaymentOnline) &&
        lpgStatus.isTrue) {
      payTab.add('آنلاین');
    }
    if (InvoiceFX.toType(typeMode.value) != 'pf' &&
        (PermissionAccess.hasPermission(PermissionsName.invoicesSellChequeReceive) || PermissionAccess.hasPermission(PermissionsName.invoicesBuyChequePay))) {
      payTab.add('اقساطی');
    }
    if (puid != null) {
      var p = PersonFX.findByUID(puid);
      personCtl.text = p.name;
      personUID.value = puid!;
      personId.value = p.id!;
    }
    if (item != null) {
      branchCtl.text = BranchFX.name(item!.branchUID);
      branchUID.value = item!.branchUID ?? '';

      var p = PersonFX.findByUID(item!.personUID);
      dateCtl.text = DateConvertor.grigoriToJalali(item!.date);
      personCtl.text = p.name;
      personUID.value = item!.personUID!;
      if (item!.parameters != null) {
        for (var d in item!.parameters!) {
          if (d['name'] == 'تخفیف' && d['mode'] == 'ded' && d['amount'] > 0) {
            discountCtl.text = Price.showWithCurrency(d['amount']);
          }
        }
      }
      Map<dynamic, dynamic> pl = item!.items!;

      productSelected.value = [];
      for (var i = 0; i < pl.keys.toList().length; i++) {
        String pUID = pl.keys.toList()[i];
        ProductDB pr = product.values.where((p) => pUID == p.uid).first;
        List<InvoiceProItemModel> proItemModelList = [];
        for (var k = 0; k < pl[pUID].length; k++) {
          //vat: {percent: 0, vatCal: true}, parameters: []
          InvoiceProItemModel proItemModel = InvoiceProItemModel(
            uid: pl[pUID][k]['prouid'],
            amount: double.parse(pl[pUID][k]['amount'].toString()),
            price: pl[pUID][k]['price'],
            buyPrice: pl[pUID][k]['buyPrice'],
            warehouseUID: pl[pUID][k]['wuid'],
            parameters: pl[pUID][k]['parameters'],
          );
          proItemModelList.add(proItemModel);
        }
        productSelected.add(
          InvoiceItemModel(
            id: pr.id!,
            uid: pr.uid!,
            pro: proItemModelList,
            name: pr.name!,
            barcode: pr.barcode!,
            type: pr.type!,
          ),
        );
      }
      if (!item!.type!.startsWith('pf')) {
        allBill = AccountingFX.allBill(item!.billUID!);
      }
      for (var element in allBill) {
        otherPay += element.paid!;
      }
      if (allBill.isNotEmpty) otherPay -= allBill[0].paid!;
      num pr = 0;
      for (var i = 0; i < allBill.length; i++) {
        pr = pr + allBill[i].paid!;
      }
      if (allBill.isNotEmpty) {
        paidCtl.text = Price.showWithCurrency(
          allBill[0].paid!,
        ); //paidFactor.value);
        deadLineCtl.text =
            allBill[0].deadLine == null || allBill[0].deadLine == ''
            ? ''
            : allBill[0].deadLine!.toString().toPersianDate();
        cash.value = allBill[0].type!;
        //thisBill.total! > thisBill.paid! ? 'credit' : 'paid';
        payTabSelect.value = cash.value == 'paid' ? 'نقدی' : 'اقساطی';
      }

      //
      for (var i = 0; i < pl.keys.length; i++) {
        String k = pl.keys.toList()[i];
        //ProductPriceDB prc = ProductFX.findPrice(pl[k]);
        ProductDB p = ProductFX.findUID(k);
        // var np = InvoiceItemModel(
        //     id: 0,
        //     uid: k,
        //     prouid: pl[k]['prouid'],
        //     name: p.name!,
        //     amount: pl[k]['amount'],
        //     type: p.type!,
        //     price: pl[k]['sellPrice'],
        //     sellPriceList: pl[k]['sellPrice'],
        //     buyPrice: pl[k]['buyPrice'],
        //     vat: p.vat!,
        //     barcode: p.barcode ?? '',
        //     warehouseUID: rxtype.value != 'buy' ? ProductFX.selectWarehouse(branchUID.value, pl[k]['prouid'], pl[i].uid!) : warehouseName.getAt(0)!.uid);

        // if (!productSelected.contains(np)) {
        //   productSelected.add(np);
        // }
      }
      addNew();
    }
    return '';
  }
}
