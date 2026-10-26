// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';

enum ConfirmType {
  DELETE,
  SAVE,
  EDIT,
  BACK,
  EXIT,
  SKIP,
  CHANGE,
  PRINT,
  DISCONNECT,
}

class Confirm {
  static con(
    context, {
    required Function onTapConfirm,
    Function? onTapCancel,
    required String confirmText,
    String? cancelText,
    String? subtex,
    String? subtext,
    required ConfirmType type,
  }) {
    MyBottomSheet.view(
      context,
      child: (s) => Column(
        spacing: 10,
        children: [
          Icon(_icon(type), color: _color(type), size: 80),
          if ((subtex ?? subtext ?? _subText(type)).isNotEmpty)
            Text(subtex ?? subtext ?? _subText(type)),
          SizedBox(height: 5),
          Row(
            children: [
              Flexible(
                child: BTN(
                  borderOnly: true,
                  color: darkMode.isFalse
                      ? AppColors.backgroundDarkMode
                      : (darkMode.value
                            ? AppColors.background
                            : AppColors.backgroundDarkMode),
                  textColor: darkMode.isFalse
                      ? AppColors.backgroundDarkMode
                      : (darkMode.value
                            ? AppColors.background
                            : AppColors.backgroundDarkMode),
                  icon: IconsaxPlusLinear.close_square,
                  onTap: () => {
                    if (onTapCancel != null) {onTapCancel()} else Get.back(),
                  },
                  //   Navigator.of(context).pop();
                  name: cancelText ?? 'انصراف',
                ),
              ),
              Flexible(
                child: BTN(
                  // wait: waitServer.value,
                  color: _color(type),
                  icon: _icon(type),
                  onTap: onTapConfirm,
                  name: confirmText,
                ),
              ),
            ],
          ),
          if (type == ConfirmType.BACK && onTapCancel != null)
            BTN(
              //  wait: waitServer.value,
              borderOnly: true,
              color: darkMode.isFalse
                  ? AppColors.backgroundDarkMode
                  : AppColors.background,
              textColor: darkMode.isFalse
                  ? AppColors.backgroundDarkMode
                  : AppColors.background,
              onTap: () {
                Get.back();
              },
              name: 'انصراف',
            ),
        ],
      ),
      showClose: false,
      isDismissible: false,
      title: _text(type),
    );
  }
}

IconData _icon(type) {
  switch (type) {
    case ConfirmType.BACK:
      return IconsaxPlusLinear.back_square;
    case ConfirmType.SAVE:
      return IconsaxPlusLinear.tick_square;
    case ConfirmType.DELETE:
      return IconsaxPlusLinear.trash_square;
    case ConfirmType.EDIT:
      return IconsaxPlusLinear.edit;
    case ConfirmType.EXIT:
      return IconsaxPlusLinear.logout_1;
    case ConfirmType.SKIP:
      return IconsaxPlusLinear.forward_square;
    case ConfirmType.CHANGE:
      return IconsaxPlusLinear.refresh_2;
    case ConfirmType.PRINT:
      return IconsaxPlusLinear.printer;
    default:
      return IconsaxPlusLinear.tick_square;
  }
}

Color _color(type) {
  switch (type) {
    case ConfirmType.BACK:
      return darkMode.isFalse
          ? AppColors.backgroundDarkMode
          : AppColors.background;
    case ConfirmType.SAVE:
      return AppColors.success;
    case ConfirmType.DELETE:
      return AppColors.error;
    case ConfirmType.EDIT:
      return AppColors.blue;
    case ConfirmType.EXIT:
      return AppColors.error;
    case ConfirmType.SKIP:
      return AppColors.yellow;
    case ConfirmType.CHANGE:
      return AppColors.yellow;
    case ConfirmType.PRINT:
      return AppColors.primary;
    default:
      return AppColors.success;
  }
}

String _text(type) {
  switch (type) {
    case ConfirmType.BACK:
      return 'تغییرات ذخیره نشده است.';
    case ConfirmType.SAVE:
      return 'از ذخیره اطلاعات اطمینان دارید؟';
    case ConfirmType.DELETE:
      return 'از حذف اطلاعات اطمینان دارید؟';
    case ConfirmType.EDIT:
      return 'از ذخیره تغییرات اطمینان دارید؟';
    case ConfirmType.EXIT:
      return 'از حساب‌کاربری خود خارج می‌شوید؟';
    case ConfirmType.SKIP:
      return 'از این مرحله رد می‌شوید؟';
    case ConfirmType.CHANGE:
      return 'تایید تغییر وضعیت';
    default:
      return '';
  }
}

String _subText(type) {
  switch (type) {
    case ConfirmType.BACK:
      return '';
    case ConfirmType.SAVE:
      return '';
    case ConfirmType.DELETE:
      return 'عملیات قابل بازگشت نیست!';
    case ConfirmType.EDIT:
      return '';
    case ConfirmType.EXIT:
      return 'برای ورود باید مجددا با شماره‌موبایل خود کد تایید دریافت کنید.';
    case ConfirmType.SKIP:
      return 'امکان بازگشت وجود ندارد.';
    default:
      return '';
  }
}
