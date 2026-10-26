// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/myTextScroll.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/cheque.dart';
import 'package:mik_data/utils/fx/persons.dart';
import 'package:mik_pages/cheque/components/form.dart';
import 'package:mik_utils/public/banks.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_variables/variable.dart';
import 'package:persian_number_utility/persian_number_utility.dart';


import 'package:mik_consts/colors.dart';

class ChequeItem extends GetView {
  ChequeDB item;
  bool end;
  bool date;
  var callback;
  ChequeItem({super.key, required this.item, required this.end, this.callback, this.date = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwipeActionCell(
          backgroundColor: Colors.transparent,
          index: item.id,
          key: ValueKey(item.id),
          firstActionWillCoverAllSpaceOnDeleting: false,
          closeWhenScrolling: false,
          trailingActions: [
            if (item.status! < 1)
              SwipeAction(
                title: 'پاس شد',
                style: TextStyle(fontSize: 10, color: darkMode.value ? Colors.white : AppColors.primaryDark),
                icon: Icon(IconsaxPlusLinear.tick_circle, color: darkMode.value ? Colors.white : AppColors.primaryDark),
                backgroundRadius: 10,
                color: AppColors.boxBackground,
                widthSpace: 70,
                forceAlignmentToBoundary: true,
                performsFirstActionWithFullSwipe: false,
                // nestedAction: SwipeNestedAction(title: "از پاس کردن چک اطمیان دارم، پاس کن!", nestedWidth: Get.width * 0.65),
                onTap: (handler) async {
                  handler(false);
                  Confirm.con(
                    context,
                    onTapConfirm: () async {
                      await ChequeFX.pass(item);
                      callback('v');
                      Get.back();
                    },
                    confirmText: 'پاس کردن چک',
                    type: ConfirmType.SAVE,
                  );
                },
              ),
            if (item.status! < 1)
              SwipeAction(
                title: 'حذف',
                style: TextStyle(fontSize: 10, color: AppColors.error),
                icon: Icon(IconsaxPlusLinear.trash_square, color: AppColors.error),
                backgroundRadius: 10,
                color: AppColors.boxBackground,
                widthSpace: 70,
                forceAlignmentToBoundary: true,
                performsFirstActionWithFullSwipe: false,
                //nestedAction: SwipeNestedAction(title: "از حذف اطمیان دارم، حذف کن!", nestedWidth: Get.width * 0.6),
                onTap: (handler) async {
                  handler(false);
                  Confirm.con(
                    context,
                    onTapConfirm: () async {
                      await ChequeFX.delete(item);
                      callback('v');
                    },
                    confirmText: 'حذف چک',
                    type: ConfirmType.DELETE,
                  );
                },
              ),
          ],
          leadingActions: [],
          child: InkWell(
            onTap: () {
              if (item.status != 1) {
                MyBottomSheet.view(
                  context,
                  child: (scrollController) => ChequeAddForm(controller: scrollController, item: item, callback: (v) => callback(v)),
                  title: item.payeeUID == '' || item.payeeUID == '-'
                      ? 'ویرایش چک دریافتی\n${(item.toUID == '' ? ChequeFX.to(item.to!) : ChequeFX.toUID(item.toUID!)).replaceAll('بابت ', '')}'
                      : 'ویرایش چک پرداختی\n${(item.toUID == '' ? ChequeFX.to(item.to!) : ChequeFX.toUID(item.toUID!)).replaceAll('بابت ', '')}',
                );
              } else {
                Alert.info('امکان ویرایش چک پاس‌شده وجود ندارد.');
              }
            },
            child: Container(
              padding: const EdgeInsets.only(right: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    maxRadius: 25,
                    backgroundColor: AppColors.boxBackground,
                    child: Icon(
                      item.holderUID == '' || item.holderUID == '-' ? IconsaxPlusLinear.money_send : IconsaxPlusLinear.money_recive,
                      color: item.status == 1
                          ? darkMode.value
                                ? Colors.white
                                : AppColors.primaryDark
                          : item.holderUID == '' || item.holderUID == '-'
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.only(left: 10),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                spacing: 10,
                                children: [
                                  Text(PersonFX.findByUID(item.holderUID! != '' && item.holderUID! != '-' ? item.holderUID : item.payeeUID)!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Flexible(child: MyTextScroll('شماره چک: ${item.chequeNo}')),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                spacing: 10,
                                children: [
                                  Flexible(child: MyTextScroll('بانک ${Banks.nameByCode(item.bankID)} - شعبه: ${item.branch!} ${item.branchNo! > 0 ? item.branchNo : ''}')),
                                  Text('مبلغ: ${Price.show(item.price!)}'),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (!date) Flexible(child: Text(item.toUID == '' ? ChequeFX.to(item.to ?? '') : ChequeFX.toUID(item.toUID ?? ''), maxLines: 1)),
                                  if (date) Flexible(child: Text('صدور: ${item.date.toString().toPersianDate()}', maxLines: 1)),
                                  if (date) Flexible(child: Text('سررسید: ${item.dueDate.toString().toPersianDate()}', maxLines: 1)),
                                ],
                              ),
                            ],
                          ),
                          if (item.status == 1 && date)
                            Container(
                              alignment: Alignment.center,
                              child: Container(
                                height: 25,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.primary, width: 2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'پاس شده',
                                  style: TextStyle(height: 1, fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
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
        ),
        EndLine(show: !end),
      ],
    );
  }
}
