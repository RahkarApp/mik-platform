// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_utils/public/banks.dart';

class BankInput extends GetView {
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
  Color? fillColor;
  String? hintText;
  BankInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.fillColor,
    this.textDirection,
    this.textAlign,
    this.readOnly,
    this.onChanged,
    this.enabled,
    this.hintText,
    this.require,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
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
      onTap: () => select(context, controller, (v) => onChanged(v)),
      enabled: enabled,
      hintText: hintText,
    );
  }

  select(context, controller, callback) {
    return Banks.listWithLogo(
      context,
      callback: (v) {
        controller.text = v.persianName;
        callback(v.code);
        Get.back();
      },
    );
  }
}
