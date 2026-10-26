// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_utils/public/color.dart';
import 'package:widget_loading/widget_loading.dart';

RxBool _wait = false.obs;

enum BTNType { ok, okContinue, edit, details, cancel, delete, none }

class BTN extends GetView {
  Function onTap;
  Function? onLongPress;
  IconData? icon;
  String name;
  Color? color;
  Color? textColor;
  BTNType? type;
  String? act;
  bool? disabled;
  bool? inLoad;
  bool borderOnly;
  bool showBorder;
  bool? navigate;
  EdgeInsets? margin;
  EdgeInsets? padding;
  bool inLine;
  double? height;
  bool? wait;
  double? width;
  BTN({
    required this.onTap,
    required this.name,
    this.showBorder = false,
    this.margin,
    this.padding,
    this.height,
    this.onLongPress,
    this.icon,
    this.color,
    this.textColor,
    this.type,
    this.act,
    this.disabled,
    this.navigate,
    this.inLine = false,
    this.borderOnly = false,
    this.inLoad = false,
    this.wait,
    this.width,
    super.key,
  });

  RxBool loading = false.obs;
  initStat() async {
    loading.value = true;

    try {
      if (!(disabled ?? false)) {
        if (!(navigate ?? false)) _wait.value = true;
        await onTap();
        _wait.value = false;
      }
    } catch (e) {
      _wait.value = false;
    }
    loading.value = false;
  }

  initStatLong() async {
    loading.value = true;
    if (!(disabled ?? false) && onLongPress != null) {
      _wait.value = true;
      await onLongPress!();
      _wait.value = false;
    }
    loading.value = false;
  }

  @override
  Widget build(BuildContext context) {
    // print('wait server is : ${waitServer.value}');
    // print('loading is : ${loading.value}');
    // print('_wait loading is : ${_wait.value}');
    // print('inload is : $inLoad');
    loading = (inLoad ?? false).obs;
    // print('loading is : ${loading.value}');

    Color effectiveTextColor =
        textColor ??
        (color != null
            ? (isColorDark(color!) ? Colors.white : Colors.black)
            : Colors.white);
    return Obx(() {
      if (type != null) {
        color = BTNDetails.color(type, act);
        icon = BTNDetails.icon(type);
      }
      return darkMode.isFalse || darkMode.isTrue
          ? Container(
              width: width,
              margin: margin ?? const EdgeInsets.all(5),
              transform: inLine
                  ? Matrix4.translationValues(0.0, 0.0, 0.0)
                  : null,
              decoration: BoxDecoration(
                border: showBorder
                    ? Border.all(color: effectiveTextColor, width: 1)
                    : borderOnly
                    ? Border.all(color: color ?? AppColors.primary, width: 1)
                    : Border.all(
                        color: (disabled ?? false)
                            ? Colors.grey
                            : color ?? AppColors.primary,
                        width: 1,
                      ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Obx(
                () => CircularWidgetLoading(
                  loading: (loading.value || _wait.value)
                      ? wait ?? (loading.value || _wait.value)
                      : wait ??
                            (loading.value || _wait.value) || waitServer.value,
                  dotRadius: 2,
                  maxLoadingCircleSize: 30,
                  dotColor: color ?? AppColors.primary,
                  child: InkWell(
                    onTap: () => initStat(),
                    onLongPress: () => initStatLong(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: height ?? (borderOnly ? 33 : 35),
                      padding: padding,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: borderOnly || type == BTNType.cancel
                            ? null
                            : (disabled ?? false)
                            ? darkMode.isFalse
                                  ? Colors.grey
                                  : Colors.grey.shade100
                            : color ?? AppColors.primary,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null)
                            Icon(
                              icon,
                              color: borderOnly || type == BTNType.cancel
                                  ? color
                                  : effectiveTextColor,
                            ),
                          if (icon != null && name != '')
                            const SizedBox(width: 5),
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: borderOnly || type == BTNType.cancel
                                  ? color
                                  : effectiveTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : Container();
    });
  }
}

class BTNDetails {
  static color(type, act) {
    switch (type) {
      case BTNType.ok:
        return AppColors.primary;
      case BTNType.okContinue:
        return AppColors.primaryDark;
      case BTNType.edit:
        return AppColors.primaryDark;
      case BTNType.details:
        switch (act) {
          case 'partner':
            return AppColors.primary;
          case 'supplier':
            return AppColors.primary;
          case 'marketer':
            return AppColors.primary;
          case 'service':
            return AppColors.primary;
          default:
            return AppColors.primary;
        }
      case BTNType.cancel:
        return darkMode.isTrue
            ? (darkMode.value
                  ? AppColors.background
                  : AppColors.backgroundDarkMode)
            : AppColors.backgroundDarkMode;
      case BTNType.delete:
        return AppColors.error;
    }
  }

  static icon(type) {
    switch (type) {
      case BTNType.ok:
        return IconsaxPlusLinear.tick_square;
      case BTNType.edit:
        return IconsaxPlusLinear.edit;
      case BTNType.okContinue:
        return IconsaxPlusLinear.arrow_square_right;
      case BTNType.details:
        return IconsaxPlusLinear.arrow_square_up;
      case BTNType.cancel:
        return IconsaxPlusLinear.close_square;
      case BTNType.delete:
        return IconsaxPlusLinear.trash_square;
      case BTNType.none:
        return IconsaxPlusLinear.element;
    }
  }
}
