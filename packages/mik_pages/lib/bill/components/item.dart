// ignore_for_file: prefer_typing_uninitialized_variables, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/input/priceInput.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/bill.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_data/utils/saveHelper.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';


import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:mik_consts/colors.dart';


class BillItem extends GetView {
  var item;
  var callback;
  bool end;
  var type;
  BillItem({super.key, required this.item, required this.callback, required this.end, this.type});
  @override
  Widget build(BuildContext context) {
    List<BillDB> details;
    double spc = 0.0;
    details = bill.values
        .where(
          (element) =>
              ((element.toUID == '' ? element.to == item['to'] : element.toUID == item['toUID']) &&
              element.debtorUID != null &&
              (((element.debtorUID!.length > 1 && element.debtorUID == item['personUID']) ||
                      element.creditorUID != null && (element.creditorUID!.length > 1 && element.creditorUID == item['personUID'])) ||
                  (element.creditorUID!.length > 1 && element.debtorUID!.length > 1))),
        )
        .toList();
    if (item['type'] == 'online' || item['type'] == 'smart') {
      var spcList = bill.values.where((element) => (element.toUID == '' ? element.to == item['to'] : element.toUID == item['toUID']) && element.type!.startsWith('spc')).toList();
      for (var element in spcList) {
        spc += element.total!;
      }
    }

    return Column(
      children: [
        SwipeActionCell(
          backgroundColor: Colors.transparent,
          index: item['id'],
          key: ValueKey(item['uid']),
          firstActionWillCoverAllSpaceOnDeleting: false,
          closeWhenScrolling: false,
          trailingActions: [
            if (item['to'].toString() == 'ff')
              SwipeAction(
                title: 'حذف',
                style: TextStyle(fontSize: 14, color: AppColors.error),
                icon: Icon(IconsaxPlusLinear.trash_square, color: AppColors.error),
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
                  _delBill(context, item, (v) {
                    callback('v');
                  });
                },
              )
            else if (((((item['toUID'] == '' ? item['to'].toString().startsWith('f') : item['toUID'].toString().startsWith('F-')) && item['to'] != '1') ||
                        ((item['toUID'] == '' ? item['to'].toString().startsWith('c') : item['toUID'].toString().startsWith('C-')) && item['to'] != '1')) &&
                    item['total'] > item['paid']) &&
                item['type'] != 'cancelled' &&
                item['type'] != 'deleted' &&
                item['type'] != 'returned')
              SwipeAction(
                title: item['mode'],
                style: TextStyle(fontSize: 14, color: darkMode.value ? Colors.white : AppColors.primaryDark),
                icon: Icon(item['mode'] == 'دریافت' ? IconsaxPlusLinear.money_recive : IconsaxPlusLinear.money_send, color: darkMode.value ? Colors.white : AppColors.primaryDark),
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
                  _addNewDebt(context, item, (v) {
                    callback('v');
                  });
                },
              ),
          ],
          leadingActions: const [],
          child: InkWell(
            onTap: () async {
              if (item['to'].toString() == 'ff') {
                Get.toNamed(
                  RoutesName.BILLADD,
                  arguments: {'mode': item['billItem'][0].creditorUID == '' || item['billItem'][0].creditorUID == '-' ? 'credit' : 'debt', 'billId': item['id'], 'billUId': item['uid']},
                );
              } else {
                if ((item['toUID'] == '' ? item['to'].toString().startsWith('f') : item['toUID'].toString().startsWith('F-')) && item['to'] != 'f0') {
                  var thisFactor = invoice.values.where((element) => element.uid == item['toUID'].toString().substring(2)).toList().first;
                  await Get.toNamed(RoutesName.INVOICEDETAIL, arguments: {'item': thisFactor, 'type': 'bill'});
                } else if ((item['to'].toString().startsWith('c') || item['toUID'].toString().startsWith('C-')) && item['to'] != '1') {
                  var thisCost = cost.values
                      .where((element) => element.uid == '' ? element.id == int.parse(item['to'].toString().substring(1)) : element.uid == item['toUID'].substring(2))
                      .toList()[0];
                  await Get.toNamed(RoutesName.COSTDETAIL, arguments: {'item': thisCost, 'type': 'bill'});
                } else {
                  showBillItems(context, item);
                }
              }
              callback('change');
            },
            child: Row(
              spacing: 5,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  margin: EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(50), color: AppColors.boxBackground),
                  child: Icon(
                    item['to'].toString().startsWith('c') || item['toUID'].toString().startsWith('C-') ? IconsaxPlusLinear.money_send : IconsaxPlusLinear.receipt,
                    color: item['type'] == 'returned' || item['type'] == 'deleted' || item['type'] == 'cancelled'
                        ? AppColors.grey
                        : item['checkout'] == true
                        ? AppColors.success
                        : AppColors.orange,
                  ),
                ),
                Flexible(
                  child: Container(
                    height: 90,
                    padding: EdgeInsets.only(left: 10),
                    width: Get.width,

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${toFind(item['to'], item['toUID'], item['mode'])} ${item['toUID'] != '1' ? typeFind(item['type']) : ""}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            Text(item['date']!.toString().toPersianDate(), style: const TextStyle(color: Colors.grey)),
                          ],
                        ),

                        Flexible(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  children: [
                                    const Icon(IconsaxPlusLinear.user, size: 18),
                                    Flexible(child: Text(item['type'] == 'online-mik' ? ' میک' : ' ${PersonFX.findByUID(item['personUID']).name}', maxLines: 1)),
                                  ],
                                ),
                              ),
                              Flexible(child: Text('کل: ${Price.show(item['total']!)}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(child: Text(type == 'credit' ? 'دریافتی: ${Price.show(item['paid']!)}' : 'پرداختی: ${Price.show(item['paid']!)}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ((item['total']! - item['paid']!) > 0 && item['type'] != 'returned' && item['type'] != 'deleted' && item['type'] != 'cancelled')
                                  ? Flexible(child: Text('مانده: ${Price.show(item['total']! - item['paid']!)}', maxLines: 1, overflow: TextOverflow.ellipsis))
                                  : billPosition(item),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        EndLine(show: !end),
      ],
    );
  }

  showBillItems(context, item) {
    RxBool isEmpty = true.obs;
    for (int i = 0; i < item['billItem'].length; i++) {
      isEmpty.value = item['billItem'][i].paid > 0 ? false : true;
      if (isEmpty.isFalse) break;
    }

    MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        children: [
          Obx(
            () => isEmpty.isTrue
                ? EmptyList(icon: IconsaxPlusLinear.receipt, text: 'هیچ ${item['mode']}ی وجود ندارد.')
                : Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(children: [for (int i = 0; i < item['billItem'].length; i++) billsItem(item['billItem'][i], i)]),
                    ),
                  ),
          ),
          if (item['paid'] < item['total'])
            BTN(
              onTap: () {
                BillFX.addNewBillForItem(
                  context,
                  [item['uid']],
                  (v) {
                    callback('v');
                    Get.back();
                  },
                  item['paid'],
                  item['mode'],
                );
              },
              name: '${item['mode']} جدید',
            ),
        ],
      ),
      title: 'لیست ${item['mode']}ها بابت ${toFind(item['to'], item['toUID'], item['mode'])} از: ${PersonFX.findByUID(item['personUID']).name}',
      initialChildSize: 0.4,
    );
  }

  bool firstPaid = true;
  billsItem(bill, index) {
    if (index == 0 && bill.paid == 0) {
      firstPaid = false;
    }
    return bill.paid > 0
        ? Column(
            children: [
              InkWell(
                onLongPress: () async {
                  if (bill.type == 'credit' || bill.type == 'paid') {
                    await Get.toNamed(RoutesName.BILLADD, arguments: {'billID': bill.id, 'billUID': bill.uid, 'mode': item['mode'] == 'دریافت' ? 'credit' : 'debt'});
                    callback('v');
                  } else {
                    Alert.info('این پرداخت قابل ویرایش نیست.');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.only(right: 20, left: 10),
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        flex: 3,
                        fit: FlexFit.tight,
                        child: Row(
                          children: [
                            SizedBox(width: 30, child: Text(firstPaid ? (index + 1).toString() : index.toString(), style: const TextStyle(fontSize: 16))),
                            Text(
                              Price.showWithCurrency(bill.paid),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.start,
                            ),
                          ],
                        ),
                      ),
                      Flexible(fit: FlexFit.tight, child: Text(bill.date.toString().toPersianDate())),
                      Flexible(
                        fit: FlexFit.tight,
                        child: Text(
                          index == 0 && bill.type == 'credit' && bill.paid > 0
                              ? '${item['mode']} قبلی'
                              : bill.type == 'credit'
                              ? 'اقساطی'
                              : bill.type == 'online'
                              ? 'آنلاین'
                              : bill.type == 'smart'
                              ? 'لینک‌هوشمند'
                              : 'نقد',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(height: 1, width: Get.width, margin: const EdgeInsets.only(right: 40), color: darkMode.isTrue ? Colors.grey.shade800 : Colors.grey.shade300),
            ],
          )
        : Container();
  }

  toFind(to, toUID, mode) {
    if (toUID == '' || toUID == null) {
      return to
          .toString()
          .replaceAll('1', mode == 'دریافت' ? 'طلب اول دوره' : 'بدهی اول دوره')
          .replaceAll('ff', 'دریافتی بدون فاکتور')
          .replaceAll('1', 'بدهی اول دوره')
          .replaceAll('f', 'فاکتور ')
          .replaceAll('c', 'هزینه ')
          .replaceAll('cm', 'کمیسیون');
    } else {
      if (toUID == '1') {
        return mode == 'دریافت' ? 'طلب اول دوره' : 'بدهی اول دوره';
      } else if (toUID == '1') {
        return mode == 'دریافت' ? 'طلب اول دوره' : 'بدهی اول دوره';
      }
      return toUID.toString().startsWith('F-')
          ? mode == 'دریافت'
                ? 'دریافتی فاکتور'
                : 'پرداختی فاکتور'
          : toUID.toString().startsWith('C-')
          ? 'پرداخت هزینه'
          : '';
    }
  }

  toUIDFind(to, mode) {
    return to
        .toString()
        .replaceAll('1', mode == 'دریافت' ? 'طلب اول دوره' : 'بدهی اول دوره')
        .replaceAll('ff', 'دریافتی بدون فاکتور')
        .replaceAll('1', 'بدهی اول دوره')
        .replaceAll('F-', 'فاکتور ')
        .replaceAll('C-', 'هزینه ')
        .replaceAll('CM', 'کمیسیون');
  }

  typeFind(type) {
    switch (type) {
      case 'online':
        return '(آنلاین)';
      case 'online-mik':
        return '(آنلاین)';
      case 'smart':
        return '(لینک)';
      case 'credit':
        return '(اقساط)';
      case 'paid':
        return '(نقدی)';
      default:
        return '';
    }
  }

  billPosition(item) {
    if (item['checkout'] == true && item['type'] != 'returned' && item['type'] != 'deleted' && item['type'] != 'cancelled') {
      return Container(
        height: 22,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.success),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          "  تسویه شده  ",
          style: TextStyle(height: 1, fontWeight: FontWeight.w600, color: AppColors.success),
        ),
      );
    } else if (item['type'] == 'returned') {
      return Container(
        height: 22,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          "  مرجوع شده  ",
          style: TextStyle(height: 1, fontWeight: FontWeight.w600, color: AppColors.grey),
        ),
      );
    } else if (item['type'] == 'cancelled') {
      return Container(
        height: 22,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          "  لغو شده  ",
          style: TextStyle(height: 1, fontWeight: FontWeight.w600, color: AppColors.grey),
        ),
      );
    } else if (item['type'] == 'deleted') {
      return Container(
        height: 22,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          "  حذف شده  ",
          style: TextStyle(height: 1, fontWeight: FontWeight.w600, color: AppColors.grey),
        ),
      );
    }
    return Container();
  }

  _delBill(context, item, callback) {
    final paidCtl = TextEditingController();
    Confirm.con(
      context,
      subtex: 'حذف ${toFind(item['to'], item['toUID'], item['mode'])} از ${PersonFX.findByUID(item['personUID']).name}',
      onTapConfirm: () async {
        for (var i = 0; i < bill.length; i++) {
          if (bill.getAt(i)!.uid == item['uid']) {
            await SaveHelper.delete(bill.getAt(i)!, i);
            Get.back();
            callback('v');
            Alert.success('صورتحساب حذف شد.');
            break;
          }
        }
      },
      confirmText: 'تایید و حذف',
      type: ConfirmType.DELETE,
    );
  }

  _addNewDebt(context, item, callback) {
    final paidCtl = TextEditingController();
    final paidF = FocusNode();
    paidF.requestFocus();
    MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        children: [
          PriceInput(name: 'مبلغ', focusNode: paidF, controller: paidCtl, desc: '   مجموع مانده: ${Price.showWithCurrency((item['total']! - item['paid']))}'),
          BTN(
            name: item['mode'],
            type: BTNType.ok,
            onTap: () {
              if (paidCtl.text.isEmpty) {
                Get.back();
              } else if (item['total']! - item['paid'] - Price.toInt(paidCtl.text) < 0) {
                Alert.error('مبلغ پرداختی نمیتواند از مانده بیشتر باشد.');
              } else {
                _okAddDebt(item, double.parse(Price.toInt(paidCtl.text).toString()), (v) => callback(v));
              }
            },
          ),
        ],
      ),
      title: 'ثبت ${item['mode']} جدید بابت ${toFind(item['to'], item['toUID'], item['mode'])}',

      //h: 250
    );
  }

  _okAddDebt(item, double price, callback) async {
    // _load = false.obs;
    BillDB it = BillDB(
      id: (ID.endId(bill)).toString().startsWith('10000') ? int.parse(ID.endId(bill).toString().substring(4)) + 1 : ID.newId(bill),
      uid: ID.uidNew(),
      debtor: item['mode'] == 'دریافت' ? item['person'] : 0,
      creditor: item['mode'] == 'دریافت' ? 0 : item['person'],
      debtorUID: item['mode'] == 'دریافت' ? item['personUID'] : '-',
      creditorUID: item['mode'] == 'دریافت' ? '-' : item['personUID'],
      total: item['total'],
      paid: price,
      unPaid: item['total']! - price - item['paid']!,
      to: item['to'],
      toUID: item['toUID'],
      date: DateTime.now().toIso8601String(),
      deadLine: item['deadLine'],
      meta: item['meta'],
      type: 'paid',
      inserter: 0,
      backup: 'new',
    );
    await SaveHelper.save(it);
    // await bill.add(it);
    // API.addBill(it.toJson());
    var thisFactor;
    if ((item['toUID'] == '' ? item['to'].toString().startsWith('f') : item['toUID'].toString().startsWith('F-')) && item['to'] != 'f0') {
      int fID = int.parse(item['to'].toString().replaceAll('f', ''));
      int index = 0;
      for (var i = 0; i < invoice.length; i++) {
        var element = invoice.getAt(i);
        if (item['toUID'] == '' ? element!.id == fID : element!.uid == item['toUID'].toString().replaceAll('F-', '')) {
          thisFactor = element;
          index = i;
        }
      }
      thisFactor.billUID!.add(it.uid);
      await SaveHelper.save(thisFactor, index: index);
      // await factor.putAt(index, thisFactor);
      // API.editFactor(thisFactor.toJson());
    } else if (item['to'].toString().startsWith('c') || item['toUID'].toString().startsWith('C-')) {
      int fID = int.parse(item['to'].toString().replaceAll('c', ''));
      var thisCost;
      int index = -1;
      for (var i = 0; i < cost.length; i++) {
        var element = cost.getAt(i);
        if (element!.uid == '' ? element.id == fID : element.uid == item['toUID'].toString().replaceAll('C-', '')) {
          thisCost = element;
          index = i;
        }
      }
      thisCost.billUID!.add(it.uid);
      await SaveHelper.save(thisCost, index: index);
      // await cost.putAt(index, thisCost);
      // API.editCost(thisCost.toJson());
    }

    Get.back();
    // Get.back();
    callback('change');
    Alert.success('پرداخت با موفقیت ثبت شد.');
  }
}
