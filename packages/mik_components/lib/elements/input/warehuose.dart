// ignore_for_file: prefer_typing_uninitialized_variables, unused_element

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/branch.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/fx/warehouse.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_utils/public/number.dart';
import 'package:mik_variables/variable.dart';

import '../bottomSheet.dart';

class WarehouseInput extends GetView {
  @override
  TextEditingController controller;
  FocusNode? focusNode;
  String name;
  TextDirection? textDirection;
  TextAlign? textAlign;
  bool? readOnly;
  bool? enabled;
  bool? require;
  var onChanged;
  String? hintText;
  double? rightPadding;
  WarehouseNameDB? removableItem;
  bool? isBox;
  String? selectedUID;
  String? branchUID;
  String? puid;
  String? prouid;
  String type;
  WarehouseInput({
    super.key,
    required this.controller,
    required this.type,
    this.branchUID,
    this.isBox = false,
    this.removableItem,
    this.selectedUID,
    this.puid,
    this.prouid = '-',
    this.focusNode,
    this.textDirection,
    this.rightPadding,
    this.textAlign,
    this.readOnly,
    required this.onChanged,
    this.enabled,
    this.hintText,
    this.require,
    required this.name,
  });
  RxString ti = ''.obs;
  //  RxInt wid = 0.obs;
  @override
  Widget build(BuildContext context) {
    if (selectedUID != null && selectedUID! != '') {
      ti.value = ProductFX.warehouseNames(selectedUID!);
    }
    if (type == 'buy') {
      Future.delayed(Duration.zero, () {
        onChanged(warehouseName.getAt(0)!.uid);
      });
    }
    return isBox != null && isBox!
        ? InkWell(
            onTap: () => select(context, controller, (v) => {onChanged(v)}),
            child: SizedBox(
              width: double.maxFinite,
              height: double.maxFinite,
              child: Obx(() {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ti.value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (selectedUID != null && selectedUID! != '')
                      const SizedBox(width: 4),
                    if (type == 'sell' &&
                        selectedUID != null &&
                        selectedUID! != '')
                      Text(
                        Number.addCommas(
                          ProductFX.productInWarehouse(
                            puid!,
                            prouid!,
                            selectedUID!,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                );
              }),
            ),
          )
        : Input(
            controller: controller,
            rightPadding: rightPadding,
            name: name,
            require: require,
            focusNode: focusNode,
            textDirection: textDirection,
            textAlign: textAlign,
            readOnly: true,
            maxLines: 1,
            minLines: 1,
            onTap: () => select(context, controller, (v) => onChanged(v)),
            enabled: enabled,
            hintText: hintText,
          );
  }

  List<WarehouseNameDB>? wl;

  select(context, ctl, callback) {
    if (type == 'buy') {
      return Alert.warning(
        'تمام خرید به انبار ${warehouseName.getAt(0)!.name} اضافه میشود.',
      );
    }
    if (branchUID != null && branchUID != '') {
      wl = BranchFX.warehouse(branchUID!);
    } else {
      wl = warehouseName.values.toList();
    }
    if (removableItem != null) {
      wl!.remove(removableItem);
    }
    RxList<WarehouseNameDB> wlf = wl!
        .where((wl) => warehouses.any((w) => wl.uid == w))
        .toList()
        .obs;
    return MyBottomSheet.view(
      context,
      child: (scrollController) => SizedBox(
        height: Get.height - 200,
        // width: Get.width * 0.9,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            MySearchBar(
              type: SearchBarType.warehouse,
              callback: (value) {
                List<WarehouseNameDB> filtter = <WarehouseNameDB>[];
                int itemSize = wl!.length;
                if (value.length > 0) {
                  for (var i = 0; i < itemSize; i++) {
                    if (wl![i].name.contains(value) ||
                        WarehouseFX.branchName(wlf[i].uid!).contains(value)) {
                      filtter.add(wl![i]);
                    }
                  }
                  wlf.value = filtter;
                } else {
                  wlf.value = wl!;
                }
              },
            ),
            Expanded(
              child: Obx(
                () => wlf.isNotEmpty
                    ? SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < wlf.length; i++)
                              InkWell(
                                onTap: () {
                                  if (type == 'buy' ||
                                      type == 'wi' ||
                                      (type != 'buy' &&
                                          type == 'wo' &&
                                          puid == null) ||
                                      (type != 'wo' &&
                                          puid != null &&
                                          puid! != '' &&
                                          ProductFX.productInWarehouse(
                                                puid!,
                                                prouid!,
                                                wlf[i].uid!,
                                              ) >
                                              0)) {
                                    Get.back();
                                    ctl.text =
                                        '${wlf[i].name} (${WarehouseFX.branchName(wlf[i].uid!)})';
                                    ti.value =
                                        '${wlf[i].name} (${WarehouseFX.branchName(wlf[i].uid!)})';
                                    callback(wlf[i].uid);
                                  } else {
                                    Alert.error(
                                      'این محصول در این انبار موجودی ندارد!',
                                    );
                                  }
                                },
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 45,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 60,
                                            height: 40,
                                            padding: const EdgeInsets.only(
                                              right: 2,
                                            ),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color:
                                                  puid != null &&
                                                      puid! != '' &&
                                                      ProductFX.productInWarehouse(
                                                            puid!,
                                                            prouid!,
                                                            wlf[i].uid!,
                                                          ) ==
                                                          0
                                                  ? AppColors.error
                                                  : AppColors.success,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(
                                                      10,
                                                    ),
                                                    bottomLeft: Radius.circular(
                                                      10,
                                                    ),
                                                  ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Container(
                                                  width: 38,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '#${wlf[i].id}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                const RotatedBox(
                                                  quarterTurns: 1,
                                                  child: Text(
                                                    'انبار',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  wlf[i].name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  WarehouseFX.branchName(
                                                    wlf[i].uid!,
                                                  ),
                                                ),
                                                if (puid != null && puid! != '')
                                                  Text(
                                                    'موجودی: ${Number.addCommas(ProductFX.productInWarehouse(puid!, prouid!, wlf[i].uid!))}',
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      height: 1,
                                      width: Get.width,
                                      margin: const EdgeInsets.only(right: 30),
                                      color: darkMode.isTrue
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade300,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      )
                    : Center(
                        child: Text(
                          'انبار با این نام وجود ندارد!',
                          style: TextStyle(
                            fontSize: 16,
                            color: darkMode.value ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      title: 'انتخاب $name',
      // h: Get.height - 180,
      //padding: const EdgeInsets.only(top: 10, left: 10, bottom: 10)
    );
  }
}

class _ItemForSelectFactor {
  var item;
  String personName;
  int total;
  int unpaid;
  _ItemForSelectFactor({
    required this.item,
    required this.personName,
    required this.total,
    required this.unpaid,
  });
}
