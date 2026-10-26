// ignore_for_file: must_be_immutable, unrelated_type_equality_checks, prefer_typing_uninitialized_variables

import 'package:auto_size_text_plus/auto_size_text_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/responsive.dart';

import 'package:mik_consts/colors.dart';

class MyTab extends GetView {
  List<String> tab;
  final Set<String>? enabledValues;
  double? height;
  double? widthSize;
  RxString value;
  bool? width;
  Color? color;
  Color? borderColor;
  List<Color>? colorByVal;
  var callback;
  EdgeInsets? padding;
  double? fontSize;
  MyTab({
    super.key,
    required this.tab,
    this.enabledValues,
    required this.value,
    required this.callback,
    this.borderColor,
    this.widthSize,
    this.height,
    this.colorByVal,
    this.width,
    this.padding,
    this.color,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (colorByVal != null && colorByVal!.length < tab.length) {
      return Text(
        'تعداد رنگها و تب‌ها برابر نیست.',
        style: TextStyle(color: AppColors.error),
      );
    }
    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < tab.length; i++)
            InkWell(
              onTap: enabledValues != null && !enabledValues!.contains(tab[i])
                  ? null
                  : () => callback(tab[i]),
              borderRadius: tab.length == 1
                  ? BorderRadius.circular(10)
                  : i == 0
                  ? const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    )
                  : i + 1 == tab.length
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    )
                  : null,
              child: Container(
                height: height,
                width: (width ?? true)
                    ? Responsive.isMobile(context)
                          ? ((Get.width - 50) / tab.length)
                          : 250
                    : Responsive.isMobile(context) || !(widthSize.isNull)
                    ? widthSize
                    : 250,
                padding: padding ?? const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: value == tab[i]
                      ? colorByVal != null
                            ? colorByVal![i]
                            : color ?? AppColors.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: (value == tab[i]
                        ? colorByVal != null
                              ? colorByVal![i]
                              : color ?? AppColors.primary
                        : borderColor ?? color ?? AppColors.primary),
                  ),
                  borderRadius: tab.length == 1
                      ? BorderRadius.circular(10)
                      : i == 0
                      ? const BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        )
                      : i + 1 == tab.length
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: AutoSizeText(
                  tab[i],
                  minFontSize: 9,
                  maxFontSize: fontSize ?? 16,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    // fontSize: fontSize ?? 16,
                    color: value == tab[i] ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
