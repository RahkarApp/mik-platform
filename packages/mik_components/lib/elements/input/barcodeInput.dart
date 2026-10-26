// ignore_for_file: prefer_typing_uninitialized_variables, annotate_overrides, prefer_final_fields, empty_catches

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/scanner.dart';
import 'package:universal_io/io.dart';

import 'input.dart';

class BarcodeInput extends GetView {
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
  String? desc;
  double? rightPadding;
  Color? fillColor;
  BarcodeInput({
    super.key,
    required this.controller,
    this.rightPadding,
    this.focusNode,
    this.textDirection,
    this.textAlign,
    this.readOnly,
    this.onChanged,
    this.enabled,
    this.require,
    this.hintText,
    this.fillColor,
    this.desc,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Input(
          controller: controller,
          name: name,
          // desc: desc,
          fillColor: fillColor,
          suffixIcon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: kIsWeb || Platform.isWindows
                ? Container()
                : InkWell(
                    onTap: () async {
                      var ll = await Scanner.barcode(context);
                      onChanged(ll ?? '');
                    },
                    child: const Icon(IconsaxPlusLinear.scan),
                  ),
          ),
          require: require,
          rightPadding: rightPadding,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textDirection: textDirection,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: textAlign,
          readOnly: readOnly,
          maxLines: 1,
          minLines: 1,
          enabled: enabled,
          hintText: hintText,
        ),
        if (desc != null) Text(desc!),
      ],
    );
  }
}
