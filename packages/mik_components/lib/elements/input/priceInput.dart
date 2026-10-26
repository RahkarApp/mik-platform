// ignore_for_file: prefer_typing_uninitialized_variables, annotate_overrides

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_utils/public/price.dart';
import 'package:mik_utils/public/number.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

class PriceInput extends GetView {
  TextEditingController controller;
  FocusNode? focusNode;
  FocusNode? nextFocus;
  TextInputType? keyboardType;
  String name;
  String? currency;
  TextDirection? textDirection;
  TextAlign? textAlign;
  bool? readOnly;
  bool? enabled;
  bool? require;
  var onChanged;
  String? hintText;
  String? desc;
  double? rightPadding;
  Color? fillColor;
  bool autoFocus;
  PriceInput({
    super.key,
    required this.controller,
    this.currency,
    this.rightPadding,
    this.focusNode,
    this.nextFocus,
    this.fillColor,
    this.keyboardType,
    this.textDirection,
    this.textAlign,
    this.readOnly,
    this.onChanged,
    this.enabled,
    this.require,
    this.hintText,
    this.desc,
    this.autoFocus = false,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Input(
          autoFocus: autoFocus,
          controller: controller,
          name: name,
          // desc: desc,
          fillColor: fillColor,
          require: require,
          rightPadding: rightPadding,
          focusNode: focusNode,
          nextFocus: nextFocus,
          keyboardType: TextInputType.number,
          inputFormatters: [CurrencyInputFormatter(currency: currency)],
          textDirection: textDirection,
          textAlign: textAlign,
          readOnly: readOnly,
          maxLines: 1,
          minLines: 1,
          onChanged: onChanged,
          enabled: enabled,
          hintText: hintText,
        ),
        if (desc != null) Text(desc!),
      ],
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  final String? currency;
  CurrencyInputFormatter({this.currency});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) {
      return newValue.copyWith(text: '');
    } else {
      final label = currency ?? Price.currency();
      final amount = Price.toInt(newValue.text.toEnglishDigit());
      final newText = '${Number.addCommas(amount)} $label';

      return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newText.length - label.length - 1,
        ),
      );
    }
  }
}
