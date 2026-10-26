import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/saveHelper.dart';
import 'package:mik_data/utils/variable.dart';
import '../../screen.dart';

class WarehouseTabDashboardController extends GetxController {
  final scl = ScrollController();
  RxList<WarehouseNameDB> st = <WarehouseNameDB>[].obs;
  init() {
    if (productDashboardController.search.value.length >= 2) {
      st.value = warehouseName.values
          .where(
            (w) =>
                w.name.toEnglishDigit().replaceAll(' ', '').toLowerCase().contains(productDashboardController.search.value.toEnglishDigit().replaceAll(' ', '').toLowerCase()) ||
                w.id.toString().toEnglishDigit().replaceAll(' ', '').toLowerCase() == productDashboardController.search.value.toEnglishDigit().replaceAll(' ', '').toLowerCase(),
          )
          .toList();
    } else if (productDashboardController.search.value.length < 2) {
      st.value = warehouseName.values.toList().toList();
    }
    return '';
  }

  addW(context, item, {index, callback}) async {
    final nameCtl = TextEditingController(text: item != null ? item.name : '');
    final nameF = FocusNode();
    nameF.requestFocus();
    List<WarehouseNameDB> warehouseNameList = warehouseName.values.toList();
    await MyBottomSheet.view(
      context,
      child: (scrollController) => Column(
        children: [
          Input(controller: nameCtl, require: true, focusNode: nameF, fillColor: darkMode.isFalse ? Colors.grey.shade300 : null, name: 'نام انبار'),
          Row(
            children: [
              Flexible(
                child: BTN(
                  onTap: () async {
                    if (item != null && item.name != nameCtl.text) {
                      for (var i = 0; i < warehouseNameList.length; i++) {
                        if (warehouseNameList[i].name.toString().replaceAll(' ', '').toLowerCase() == nameCtl.text.toString().replaceAll(' ', '').toLowerCase()) {
                          return Alert.error('نام انبار تکراری است!');
                        }
                      }
                    }
                    if (nameCtl.text.isNotEmpty) {
                      nameF.unfocus();
                      WarehouseNameDB nw = WarehouseNameDB(
                        id: item != null ? item.id : ID.newId(warehouseName),
                        uid: item != null ? item.uid : ID.uidNew(),
                        name: nameCtl.text,
                        active: true,
                        inserter: 0,
                        backup: item == null ? 'new' : 'edit',
                      );
                      await SaveHelper.save(nw, index: item != null ? index : null);
                      init();
                      Get.back();
                      if (item != null) {
                        Get.back();
                      }
                      Alert.success('${item != null ? 'ویرایش انبار' : 'افزودن انبار'} با موفقیت انجام شد.');
                      if (callback != null) callback(nw.uid);
                    } else {
                      Alert.error('نام انبار را وارد کنید.');
                    }
                  },
                  type: BTNType.ok,
                  name: item != null ? 'ویرایش انبار' : 'افزودن انبار',
                ),
              ),
              Flexible(
                child: BTN(
                  onTap: () {
                    Get.back();
                  },
                  type: BTNType.cancel,
                  name: 'انصراف',
                ),
              ),
            ],
          ),
        ],
      ),
      title: item == null ? 'افزودن انبار جدید' : 'ویرایش انبار',
    );
  }
}
