// ignore_for_file: prefer_typing_uninitialized_variables, unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_data/source/remote/models/pim_category.dart';

import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/utils/fx/cost.dart';
import 'package:mik_pages/product/screen/tabs/cat/cat_multi_select_tree_view.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:mik_consts/colors.dart';

import '../buttons/button.dart';

class CatInput extends GetView {
  @override
  TextEditingController controller;
  FocusNode? focusNode;
  FocusNode? nextFocus;
  String name;
  TextDirection? textDirection;
  TextAlign? textAlign;
  bool? readOnly;
  bool? enabled;
  bool? require;
  bool? multi;
  var onChanged;
  String? hintText;
  Jalali? firstDate;
  List<String>? selected;
  final List<PimCategory>? categories;
  bool? onlyProductCatAdd;

  ///cost,product
  String type;
  CatInput({
    super.key,
    required this.controller,
    required this.type,
    this.multi,
    this.onlyProductCatAdd,
    this.selected,
    this.categories,
    this.focusNode,
    this.nextFocus,
    this.textDirection,
    this.textAlign,
    this.readOnly,
    required this.onChanged,
    this.enabled,
    this.hintText,
    this.require,
    this.firstDate,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Input(
      controller: controller,
      name: name,
      require: require,
      focusNode: focusNode,
      nextFocus: nextFocus,
      textDirection: textDirection,
      textAlign: textAlign,
      readOnly: true,
      maxLines: 1,
      minLines: 1,
      onTap: () => type == 'cost'
          ? costCatSelect(context, selected, (v) => onChanged(v))
          : productCatSelct(context, (v) => onChanged(v)),
      enabled: enabled,
      hintText: hintText,
      suffixIcon: controller.text.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: InkWell(
                onTap: () {
                  onChanged([]);
                },
                child: const Icon(IconsaxPlusLinear.close_square),
              ),
            )
          : null,
    );
  }

  costCatSelect(context, List? selectedItem, callback) {
    RxList catList = [].obs;
    //int? selectedItem;
    // if (costCategory.isNotEmpty) {
    catList.value = costCategory.values.where((element) => true).toList();
    return MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          MySearchBar(
            type: SearchBarType.category,
            callback: (value) {
              var filtter = [];
              int itemSize = costCategory.length;
              if (value.length > 0) {
                for (var i = 0; i < itemSize; i++) {
                  if (costCategory
                      .getAt(i)!
                      .name!
                      .toLowerCase()
                      .toEnglishDigit()
                      .contains(
                        value.toString().toLowerCase().toEnglishDigit(),
                      )) {
                    filtter.add(costCategory.getAt(i)!);
                  }
                }
                catList.value = filtter;
              } else {
                catList.value = costCategory.values
                    .where((element) => true)
                    .toList();
              }
            },
          ),
          Expanded(
            child: Obx(
              () => catList.isNotEmpty
                  ?
                    // GridView.count(
                    //     controller: scrollController,
                    //     crossAxisCount: 3,
                    //     mainAxisSpacing: 8,
                    //     crossAxisSpacing: 8,
                    //     childAspectRatio: 3.2,
                    SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        children: [
                          for (var i = 0; i < catList.length; i++)
                            if (catList[i] != '')
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  callback({
                                    'name': catList[i]!.name,
                                    'uid': catList[i]!.uid,
                                  });
                                  Get.back();
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      catList[i].name ?? '',
                                      style: TextStyle(
                                        color:
                                            selectedItem != null &&
                                                selectedItem.contains(
                                                  catList[i].uid,
                                                )
                                            ? darkMode.value
                                                  ? Colors.white
                                                  : null
                                            : null,
                                        fontWeight:
                                            selectedItem != null &&
                                                selectedItem.contains(
                                                  catList[i].uid,
                                                )
                                            ? FontWeight.bold
                                            : null,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'شناسه: ${catList[i]!.id}',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 10,
                                        height: 2,
                                      ),
                                    ),
                                    selected:
                                        selectedItem != null &&
                                        selectedItem.contains(catList[i].uid),
                                    leading: Checkbox(
                                      value:
                                          selectedItem != null &&
                                          selectedItem.contains(catList[i].uid),
                                      onChanged: (bool? value) {
                                        callback({
                                          'name': catList[i]!.name,
                                          'uid': catList[i]!.uid,
                                        });
                                        Get.back();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    )
                  : Center(
                      child: Text(
                        'دسته‌بندی وجود ندارد!',
                        style: TextStyle(
                          fontSize: 16,
                          color: darkMode.value ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(
                  child: BTN(
                    name: 'دسته‌بندی جدید',
                    icon: IconsaxPlusLinear.add,
                    color: AppColors.success,
                    onTap: () async {
                      Get.back();
                      CostFX.addCat(
                        context,
                        callback: (v) {
                          callback(v);
                        },
                      );
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
              ],
            ),
          ),
        ],
      ),
      title: 'دسته‌بندی هزینه',
      initialChildSize: 0.6,
    );
    // } else {
    // CostFX.addCat(context, callback: (v) {
    //   callback(v);
    // });
    // }
  }

  productCatSelct(context, callback, {notadd}) {
    RxList catList = [].obs;
    catList.value =
        categories ??
        category.values
            .where(
              (element) =>
                  element.type == type ||
                  (type == 'product' && element.type == null),
            )
            .toList();
    RxList<String> selectedItem = (selected ?? <String>[]).obs;

    //if (catList.isNotEmpty) {
    String typeString = type == 'product' ? 'کالا' : 'خدمت';

    return MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: CategoryMultiSelectTreeView(
              type: type,
              categories: categories,
              selectedCategoryIds: selected,
              scrollController: scrollController,
              onCategorySelected: (v) {
                selectedItem.value = v ?? [];
                if (!(multi ?? true)) {
                  Get.back();
                  callback({
                    'name':
                        categories
                            ?.firstWhere((e) => e.id == selectedItem[0])
                            .name ??
                        category.values
                            .firstWhere((e) => e.uid == selectedItem[0])
                            .name,
                    'uid': selectedItem[0],
                  });
                }
              },
            ),
          ),
          if ((multi ?? true))
            BTN(
              onTap: () {
                var d = [];
                for (var i = 0; i < selectedItem.length; i++) {
                  d.add({
                    'name':
                        categories
                            ?.firstWhere((e) => e.id == selectedItem[i])
                            .name ??
                        category.values
                            .firstWhere((e) => e.uid == selectedItem[i])
                            .name,
                    'uid': selectedItem[i],
                  });
                }
                Get.back();
                callback(d);
              },
              type: BTNType.ok,
              name: 'تایید',
            ),
        ],
      ),
      title: 'دسته‌بندی‌های $typeString',
      initialChildSize: 0.8,
    );
    // } else {
    //   ProductFX.addCat(context, type: type, callback: (v) {
    //     callback([
    //       {'name': v['name'], 'uid': v['uid']}
    //     ]);
    //   });
    // }
  }
}
