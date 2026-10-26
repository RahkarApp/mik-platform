// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_consts/colors.dart';

import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import 'package:persian_number_utility/persian_number_utility.dart';

class SelectListInput extends GetView {
  @override
  TextEditingController controller;
  FocusNode? focusNode;
  String name;
  List<String> list;
  TextDirection? textDirection;
  TextAlign? textAlign;
  bool? readOnly;
  bool? enabled;
  bool? require;
  var onChanged;
  String? hintText;
  Color? fillColor;

  SelectListInput({
    super.key,
    required this.controller,
    required this.list,
    this.focusNode,
    this.fillColor,
    this.textDirection,
    this.textAlign,
    this.readOnly,
    required this.onChanged,
    this.enabled,
    this.hintText,
    this.require,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    // if (controller.text.isEmpty && !(require ?? true)) {
    //   controller.text = DateConvertor.jalaliNow();
    // }
    return Input(
      controller: controller,
      name: name,
      fillColor: fillColor,
      require: require,
      focusNode: focusNode,
      textDirection: textDirection,
      textAlign: textAlign,
      readOnly: true,
      maxLines: 1,
      minLines: 1,
      onTap: () => select(context, (v) => onChanged(v)),
      enabled: enabled,
      hintText: hintText,
    );
  }

  select(context, callback) {
    RxList<String> data = list.obs;
    MyBottomSheet.view(
      context,
      child: (s) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MySearchBar(
            controller: TextEditingController(),
            type: SearchBarType.text,
            callback: (v) {
              print('v is $v');
              data.value = list.where((e) => e.contains(v)).toList();
            },
          ),
          Container(
            height: Get.height * 0.5,
            child: Obx(
              () => ListView.builder(
                controller: s,
                itemCount: data.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      callback(data[index]);
                      Get.back();
                    },
                    child: Container(
                      margin: EdgeInsets.all(5),
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 15,
                      ),
                      width: Get.width,
                      decoration: BoxDecoration(
                        color: controller.text == data[index]
                            ? AppColors.secondary.withValues(alpha: 1)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(data[index]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      // initialChildSize: 0.5,
      title: 'انتخاب $name',
    );
  }
}
