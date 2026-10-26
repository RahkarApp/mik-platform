// ignore_for_file: annotate_overrides

import 'package:flutter/material.dart';
import 'package:mik_data/source/remote/models/business_branch.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_data/utils/variable.dart';

import 'package:mik_consts/colors.dart';

import '../bottomSheet.dart';

import 'searchbar.dart';

class BranchInput extends GetView {
  final List<BusinessBranch>? remoteItems;
  TextEditingController controller;
  FocusNode? focusNode;
  String name;
  bool? readOnly;
  TextDirection? textDirection;
  TextAlign? textAlign;
  bool? enabled;
  bool? require;
  var onChanged;
  String? hintText;
  String? desc;
  double? rightPadding;
  Color? fillColor;
  BranchInput({
    super.key,
    required this.controller,
    this.readOnly,
    this.remoteItems,
    this.rightPadding,
    this.fillColor,
    this.focusNode,
    this.require,
    this.textDirection,
    this.textAlign,
    required this.onChanged,
    this.enabled,
    this.hintText,
    this.desc,
    required this.name,
  });
  @override
  Widget build(BuildContext context) {
    return Input(
      controller: controller,
      name: name,
      fillColor: fillColor,
      rightPadding: rightPadding,
      require: require,
      focusNode: focusNode,
      textDirection: textDirection,
      textAlign: textAlign,
      readOnly: true,
      maxLines: 1,
      minLines: 1,
      onTap: () => (readOnly ?? false)
          ? {Alert.warning('شعبه قابل تغییر نیست.')}
          : select(context, controller, (uid) => onChanged(uid)),
      enabled: enabled,
      hintText: hintText,
    );
  }

  List branchList = [];
  RxList filtteredBranch = [].obs;
  select(context, ctl, callback) {
    branchList = remoteItems != null
        ? remoteItems!.where((b) => b.status == 'ACTIVE').toList()
        : branch.values
              .where((b) => b.active! && branchs.contains(b.uid))
              .toList();

    filtteredBranch.value = branchList;
    return MyBottomSheet.view(
      context,
      child: (d) => SizedBox(
        height: (Get.height * 0.8) - 75,
        // width: Get.width * 0.9,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Text(,
            //     style: TextStyle(
            //         fontSize: 20,
            //         color: darkMode.value ? Colors.white : Colors.black)),
            Row(
              children: [
                Flexible(
                  child: MySearchBar(
                    type: SearchBarType.user,
                    callback: (value) {
                      var filtter = [];
                      int itemSize = branchList.length;
                      if (value.length > 0) {
                        for (var i = 0; i < itemSize; i++) {
                          if (branchList[i].name.contains(value)) {
                            filtter.add(branchList[i]);
                          }
                        }
                        filtteredBranch.value = filtter;
                      } else {
                        filtteredBranch.value = branchList;
                      }
                    },
                  ),
                ),
              ],
            ),
            Expanded(
              child: Obx(
                () => filtteredBranch.isNotEmpty
                    ? SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < filtteredBranch.length; i++)
                              InkWell(
                                onTap: () {
                                  Get.back();
                                  // _change.toggle();
                                  controller.text = filtteredBranch[i].name;
                                  final item = filtteredBranch[i];
                                  callback(
                                    item is BusinessBranch
                                        ? item.branchId
                                        : item.uid,
                                  );
                                },
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 45,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                maxRadius: 20,
                                                backgroundColor:
                                                    AppColors.boxBackground,
                                                child: Icon(
                                                  IconsaxPlusLinear.shop,
                                                  color: darkMode.isFalse
                                                      ? AppColors
                                                            .backgroundDarkMode
                                                      : AppColors.background,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                filtteredBranch[i].name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: darkMode.value
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                            ],
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
                          'شعبه‌ای با این نام وجود ندارد!',
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
      title: 'انتخاب شعبه',
      initialChildSize: 0.5,
    );
  }
}
