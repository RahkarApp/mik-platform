// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as SaveHelper;
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/utils/fx/cost.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/variable.dart';


class CategoryItem extends GetView {
  var item;
  String type;
  int index;
  var callback;
  CategoryItem({required this.item, required this.index, required this.type, required this.callback, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          // onTap: () => callback != null ? callback(item.id) : null,
          child: Row(
            children: [
              const SizedBox(width: 10),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(color: AppColors.boxBackground, borderRadius: BorderRadius.circular(5)),
                child: Icon(
                  type == 'product'
                      ? item.type == 'service'
                            ? IconsaxPlusLinear.tag_2
                            : IconsaxPlusLinear.box
                      : IconsaxPlusLinear.money_send,
                  size: 40,
                  color: AppColors.disable,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [Text(item.name, maxLines: 1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))],
                          ),
                        ),
                        Container(padding: const EdgeInsets.only(left: 10), child: Text('کد: ${ProductFX.showID(item.id)}')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(fit: FlexFit.tight, child: Text(type == 'cost' ? '${CostFX.inCat(item.uid)}' : 'اقلام: ${ProductFX.inCat(item.uid)}')),
                        Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                await edit(context);
                              },
                              child: Container(padding: const EdgeInsets.all(8), child: const Icon(IconsaxPlusLinear.edit_2)),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                if (type == 'cost' ? CostFX.inCat(item.uid) > 0 : ProductFX.inCat(item.uid) > 0) {
                                  Alert.error('فقط دسته‌بندی‌های خالی را میتوانید حذف کنید.');
                                } else {
                                  Confirm.con(
                                    context,
                                    onTapConfirm: () async {
                                      if (type == 'cost' ? CostFX.inCat(item.uid) > 0 : ProductFX.inCat(item.uid) > 0) {
                                        Alert.error('فقط دسته‌بندی‌های خالی را میتوانید حذف کنید.');
                                      } else {
                                        await SaveHelper.delete(item,);
                                        callback('v');
                                      }
                                    },
                                    confirmText: 'تایید و حذف',
                                    type: ConfirmType.DELETE,
                                  );
                                }
                              },

                              child: Container(padding: const EdgeInsets.all(8), child: const Icon(IconsaxPlusLinear.trash)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        EndLine(),
        if (index != category.length - 1) const SizedBox(height: 5),
        if ((type == 'product' && index == category.length - 1) || (type == 'cost' && index == costCategory.length - 1)) const SizedBox(height: 60),
      ],
    );
  }

  edit(context) async {
    if (type == 'cost') {
      await CostFX.addCat(
        context,
        callback: (v) {
          callback('v');
        },
        index: index,
      );
    } else {
      await ProductFX.editCat(
        Get.context!,
        index: index,
        callback: (v) {
          callback('v');
        },
      );
    }
  }
}
