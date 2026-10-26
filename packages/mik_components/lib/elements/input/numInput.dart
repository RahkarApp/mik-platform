// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/input/input.dart';

class NumberInput extends GetView {
  @override
  TextEditingController controller;
  FocusNode? focusNode;
  TextInputType? keyboardType;
  String name;
  TextDirection? textDirection;
  TextAlign? textAlign;
  bool? readOnly;
  int? maxLines;
  int? minLines;
  int? maxLength;
  bool? enabled;
  bool? require;
  double? rightPadding;
  List<TextInputFormatter>? inputFormatters;
  var onChanged;
  var onTap;
  Widget? suffixIcon;
  String? hintText;
  Color? fillColor;
  NumberInput({
    super.key,
    required this.controller,
    this.suffixIcon,
    this.focusNode,
    this.inputFormatters,
    this.keyboardType,
    this.rightPadding,
    this.textDirection,
    this.textAlign,
    this.readOnly,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.enabled,
    this.hintText,
    this.require,
    this.fillColor,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Input(
      controller: controller,
      name: name,
      require: require,
      rightPadding: rightPadding,
      focusNode: focusNode,
      keyboardType: keyboardType ?? TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
        ...(inputFormatters ?? []),
      ],
      fillColor: fillColor,
      suffixIcon: suffixIcon,
      textDirection: textDirection,
      textAlign: textAlign,
      readOnly: readOnly,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onTap: onTap,
      enabled: enabled,
      hintText: hintText,
    );
  }
}
