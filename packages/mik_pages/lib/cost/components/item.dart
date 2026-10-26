// ignore_for_file: must_be_immutable, prefer_typing_uninitialized_variables
import 'package:flutter/material.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_components/elements/myTextScroll.dart';

import 'package:mik_consts/colors.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/cost.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/saveHelper.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_utils/public/date.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';


class CostItem extends GetView {
  var item;
  var callback;
  bool end;
  bool? shippingCost;
  var type;
  CostItem({super.key, required this.item, required this.callback, required this.end, this.type});
  RxBool change = false.obs;
  @override
  Widget build(BuildContext context) {
    var thisBill = bill.values.where((element) => item.billUID.contains(element.uid)).toList();
    var paid = 0.0;
    for (var i = 0; i < thisBill.length; i++) {
      paid = paid + thisBill[i].paid!;
    }
    bool isPaid = false;
    if (thisBill.isNotEmpty) isPaid = thisBill.first.total == paid;
    return Obx(
      () => change.isTrue || change.isFalse
          ? Column(
              children: [
                SwipeActionCell(
                  backgroundColor: Colors.transparent,
                  index: item.id,
                  key: ValueKey(item.id),
                  firstActionWillCoverAllSpaceOnDeleting: false,
                  closeWhenScrolling: false,
                  trailingActions: item.runtimeType.toString() == 'InvoiceDB'
                      ? []
                      : [
                          if (!isPaid)
                            SwipeAction(
                              title: 'پرداخت',
                              style: TextStyle(fontSize: 10, color: darkMode.value ? Colors.white : AppColors.primaryDark),
                              icon: Icon(IconsaxPlusLinear.card, color: darkMode.value ? Colors.white : AppColors.primaryDark),
                              backgroundRadius: 10,
                              color: AppColors.boxBackground,
                              widthSpace: 50,
                              forceAlignmentToBoundary: true,
                              performsFirstActionWithFullSwipe: false,
                              // nestedAction: SwipeNestedAction(
                              //     title: "از حذف اطمیان دارم، حذف کن!",
                              //     nestedWidth: Get.width * 0.6),
                              onTap: (handler) async {
                                handler(false);
                                addNewDebt(context, item.billUID, callback, paid);
                              },
                            ),
                          SwipeAction(
                            title: 'ویرایش',
                            style: TextStyle(fontSize: 10, color: darkMode.value ? Colors.white : AppColors.primaryDark),
                            icon: Icon(IconsaxPlusLinear.edit, color: darkMode.value ? Colors.white : AppColors.primaryDark),
                            backgroundRadius: 10,
                            color: AppColors.boxBackground,
                            widthSpace: 50,
                            forceAlignmentToBoundary: true,
                            performsFirstActionWithFullSwipe: false,
                            // nestedAction: SwipeNestedAction(
                            //     title: "از حذف اطمیان دارم، حذف کن!",
                            //     nestedWidth: Get.width * 0.6),
                            onTap: (handler) async {
                              handler(false);
                              await Get.toNamed(RoutesName.COSTADD, arguments: {'item': item});
                              callback('change');
                            },
                          ),
                          SwipeAction(
                            title: 'حذف',
                            style: TextStyle(fontSize: 10, color: AppColors.error),
                            icon: Icon(IconsaxPlusLinear.trash_square, color: AppColors.error),
                            backgroundRadius: 10,
                            color: AppColors.boxBackground,
                            widthSpace: 50,
                            forceAlignmentToBoundary: true,
                            performsFirstActionWithFullSwipe: false,
                            onTap: (handler) async {
                              handler(false);
                              await CostFX.del(context, item, (v) {
                                callback('change');
                              });
                            },
                          ),
                        ],
                  leadingActions: item.runtimeType.toString() == 'InvoiceDB' ? [] : [],
                  child: InkWell(
                    onTap: () async {
                      if (item.runtimeType.toString() == 'InvoiceDB') {
                        InvoiceFX.sendOrder(
                          item,
                          3,
                          edit: true,
                          callback: (v) {
                            item = v;
                            change.toggle();
                          },
                        );
                      } else {
                        await Get.toNamed(RoutesName.COSTDETAIL, arguments: {'item': item});
                      }

                      callback('change');
                    },
                    child: Container(
                      padding: const EdgeInsets.only(right: 20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            maxRadius: 25,
                            backgroundColor: AppColors.boxBackground,
                            child: Icon(IconsaxPlusLinear.receipt_2, color: darkMode.value ? AppColors.primaryLite : AppColors.primaryDark),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: SizedBox(
                              height: 60,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            spacing: 10,
                                            children: [
                                              Flexible(
                                                child: MyTextScroll(
                                                  item.runtimeType.toString() == 'InvoiceDB'
                                                      ? item.shipping['company'] == '' || item.shipping['company'] == null
                                                            ? 'ارسال سفارش'
                                                            : 'ارسال با ${item.shipping['company']}'
                                                      : item.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              if (type == null)
                                                Flexible(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    spacing: 3,
                                                    children: [
                                                      const Icon(IconsaxPlusLinear.user, size: 18),
                                                      Flexible(
                                                        child: Text(
                                                          ((item.description ?? '').contains('کد رهگیری:') && item.description.contains('شماره مرجع:') && item.description.contains('شماره سفارش:'))
                                                              ? 'میک'
                                                              : PersonFX.findByUID(item.personUID).name,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              // Text(
                                              //   item.date
                                              //       .toString()
                                              //       .toPersianDate(),
                                              //   style: const TextStyle(
                                              //       color: Colors.grey),
                                              // )
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(Price.showWithCurrency(item.runtimeType.toString() == 'InvoiceDB' ? item.shipping['cost'] : item.price)),
                                            (item.runtimeType.toString() != 'InvoiceDB' && item.factorID > 0) || item.runtimeType.toString() == 'InvoiceDB'
                                                ? Row(
                                                    spacing: 2,
                                                    children: [
                                                      Text(item.runtimeType.toString() == 'InvoiceDB' ? DateConvertor.grigoriToJalali(DateTime.parse(item.date)) : ''),
                                                      const Icon(IconsaxPlusLinear.receipt_text, size: 18),
                                                      const SizedBox(width: 3),
                                                      Text(item.runtimeType.toString() == 'InvoiceDB' ? item.id.toString() : item.factorID.toString()),
                                                    ],
                                                  )
                                                : Container(width: 22.5),
                                            if (item.runtimeType.toString() != 'InvoiceDB')
                                              Text(isPaid ? 'تسویه شده' : 'تسویه نشده', style: TextStyle(color: isPaid ? AppColors.success : AppColors.error)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                EndLine(show: !end),
              ],
            )
          : Container(),
    );
  }

  costCatFind(String uid) {
    var cc = costCategory.values.where((element) => element.uid == uid).toList();

    return uid == ''
        ? 'کسب‌وکار'
        : cc.isNotEmpty
        ? cc[0].name
        : '';
  }
}

addNewDebt(context, List<String> billUID, callback, paid) {
  var item = bill.values.where((element) => element.uid == billUID[0]).toList()[0];
  final paidCtl = TextEditingController();
  final paidF = FocusNode();
  paidF.requestFocus();
  MyBottomSheet.view(
    context,
    child: (scrollController) => Column(
      children: [
        PriceInput(name: 'مبلغ', focusNode: paidF, controller: paidCtl, desc: '   مجموع مانده: ${Price.showWithCurrency(item.total! - paid)}'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: BTN(
                name: 'افزودن',
                type: BTNType.ok,
                onTap: () {
                  if (paidCtl.text.isEmpty) {
                    Get.back();
                  } else if (item.total! - paid - Price.toInt(paidCtl.text) < 0) {
                    Alert.error('مبلغ پرداختی نمیتواند از مانده بیشتر باشد.');
                  } else {
                    okaddBillCost(item, double.parse('${Price.toInt(paidCtl.text)}.0'), callback);
                  }
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
    // h: 180,
    title: 'ثبت پرداخت جدید برای ${toFind(item.to)}',
  );
}

okaddBillCost(BillDB item, double price, callback) async {
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
  var thisCost;
  if ((item.to.toString().startsWith('f') || item.toUID.toString().startsWith('F-')) && item.to != 'f0') {
    int fID = int.tryParse(item.to.toString().replaceAll('f', '')) ?? 0;
    var thisFactor;

    int index = -1;
    for (var i = 0; i < invoice.length; i++) {
      var element = invoice.getAt(i);
      if (item.toUID == '' ? element!.id == fID : element!.uid == item.toUID!.replaceAll('F-', '')) {
        thisFactor = element;
        index = i;
      }
    }
    thisFactor.billUID!.add(it.uid);
    await SaveHelper.save(thisFactor, index: index);
    // await factor.putAt(index, thisFactor);
    // API.editFactor(thisFactor.toJson());
  } else if (item.to.toString().startsWith('c') || item.toUID.toString().startsWith('C-')) {
    int fID = int.parse(item.to.toString().replaceAll('c', ''));

    int index = -1;
    for (var i = 0; i < cost.length; i++) {
      var element = cost.getAt(i);
      if (element!.uid == '' ? element.id == fID : element.uid == item.toUID.toString().replaceAll('C-', '')) {
        thisCost = element;
        index = i;
      }
    }
    thisCost.billUID!.add(it.uid);
    await SaveHelper.save(thisCost, index: index);
    // await cost.putAt(index, thisCost);
    // API.editCost(thisCost.toJson());
  }
  callback('change');
  // Get.back();
  Get.back();
  Alert.success('پرداخت با موفقیت برای هزینه ${thisCost.id} ثبت شد.');
}

toFind(to) {
  return to.toString().replaceAll('f0', 'اول دوره').replaceAll('ff', 'دریافتی بدون فاکتور').replaceAll('c0', 'اول دوره').replaceAll('f', 'فاکتور ').replaceAll('c', 'هزینه ');
}
