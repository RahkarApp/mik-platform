// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:auto_size_text_plus/auto_size_text_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';

// RxBool _waitServer = false.obs;

class MiniBTN extends GetView {
  String name;
  Color? color;
  Color? itemColor;
  void Function()? onTap;
  void Function()? onLongPress;
  var icon;
  double? fontSize;
  double? iconSize;
  int? flex;
  double? height;
  EdgeInsets? margin;
  bool? noFlex;
  MiniBTN({
    required this.name,
    this.color,
    required this.icon,
    required this.onTap,
    this.fontSize,
    this.iconSize,
    this.height,
    this.onLongPress,
    this.margin,
    this.itemColor,
    this.flex,
    this.noFlex = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return !(noFlex ?? false)
        ? Flexible(fit: FlexFit.tight, flex: flex ?? 1, child: child())
        : child();
  }

  Container child() {
    return Container(
      margin: margin ?? const EdgeInsets.all(5),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: Obx(
            () => darkMode.isFalse || darkMode.isTrue
                ? Container(
                    alignment: Alignment.center,
                    // width: double.infinity, //Get.width / 6,
                    height: height ?? 60,
                    decoration: BoxDecoration(
                      color:
                          color ??
                          (darkMode.isFalse
                              ? Colors.grey.shade100
                              : Colors.grey.shade900),
                      border: (color == Colors.transparent)
                          ? Border.all(
                              color:
                                  (itemColor ??
                                  (darkMode.isFalse
                                      ? AppColors.primaryDark
                                      : AppColors.primary)),
                            )
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon is IconData
                            ? Icon(
                                icon,
                                size: iconSize ?? 20,
                                color:
                                    (itemColor ??
                                    (darkMode.isFalse
                                        ? AppColors.primaryDark
                                        : AppColors.primary)),
                              )
                            : icon,
                        AutoSizeText(
                          name,
                          maxLines: 1,
                          minFontSize: 10,
                          style: TextStyle(
                            fontSize: fontSize ?? 12,
                            color:
                                (itemColor ??
                                (darkMode.isFalse
                                    ? AppColors.primaryDark
                                    : AppColors.primary)),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(),
          ),
        ),
      ),
    );
  }
}
