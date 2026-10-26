// ignore_for_file: file_names, constant_pattern_never_matches_value_type

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:mik_consts/colors.dart';

class InvoiceStatus {
  static List get codeList => [1, 2, 3, 8, 9, 100, 900, 901, 444, null];
  static List get nameList => ['ثبت شده', 'آماده ارسال', 'ارسال شده', 'لغو شده', 'مرجوع شده', 'تحویل شده', 'پیش‌فاکتور', 'تبدیل به فاکتور‌ شده', 'خرید حذف شده', 'خرید'];
  static int findLastStatusCode(List status) {
    if (status.isNotEmpty) {
      List sortedStatus = List.from(status);
      sortedStatus.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
      return sortedStatus[0]['status'] ?? 0;
    }
    return 0;
  }

  static String findLastStatusDate(List status) {
    if (status.isNotEmpty) {
      List sortedStatus = List.from(status);
      sortedStatus.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
      return sortedStatus[0]['date'] ?? '';
    }
    return '';
  }

  static Widget check(paid, int status) {
    if (status > 3) {
      return Text(
        name(status),
        textAlign: TextAlign.center,
        style: TextStyle(height: 1, color: color(status)),
      );
    } else {
      return Text(
        paid ? 'تسویه‌شده' : 'تسویه نشده',
        textAlign: TextAlign.center,
        style: TextStyle(height: 1, color: paid ? Colors.green : Colors.red),
      );
    }
  }

  static Color color(int status) {
    switch (status) {
      case 0:
        return AppColors.primaryLite;
      case 1:
        return AppColors.primaryLite;
      case 2:
        return AppColors.blue;
      case 3:
        return AppColors.yellow;
      case 8:
        return AppColors.grey;
      case 9:
        return AppColors.error;
      case 100:
        return AppColors.success;
      case 900:
        return AppColors.primaryDark;
      case 901:
        return AppColors.primaryDark;
      case 444:
        return AppColors.error;
      default:
        return AppColors.primaryLite;
    }
  }

  // static String iconImg(status) {
  //   switch (status) {
  //     case 0:
  //       return 'assets/images/icon/BuySubmit.png';
  //     case 1:
  //       return 'assets/images/icon/BuySubmit.png';
  //     case 2:
  //       return 'assets/images/icon/box.png';
  //     case 3:
  //       return 'assets/images/icon/posted.png';
  //     case 9:
  //       return 'assets/images/icon/reject.png';
  //     case 8:
  //       return 'assets/images/icon/cancel.png';
  //     default:
  //       return 'assets/images/icon/BuySubmit.png';
  //   }
  // }

  static IconData icon(int status) {
    switch (status) {
      case 0:
        return IconsaxPlusLinear.box_search;
      case 1:
        return IconsaxPlusLinear.box_search;
      case 2:
        return IconsaxPlusLinear.box;
      case 3:
        return IconsaxPlusLinear.truck_tick;
      case 9:
        return IconsaxPlusLinear.d_rotate;
      case 8:
        return IconsaxPlusLinear.box_remove;
      case 100:
        return IconsaxPlusLinear.box_tick;
      case 900:
        return IconsaxPlusLinear.receipt_search;
      case 901:
        return IconsaxPlusLinear.receipt;
      case 444:
        return IconsaxPlusLinear.close_circle;
      default:
        return IconsaxPlusLinear.box_search;
    }
  }

  static String name(int? status) {
    switch (status) {
      case 0:
        return '';
      case 1:
        return 'ثبت شده';
      case 2:
        return 'آماده ارسال';
      case 3:
        return 'ارسال شده';
      case 9:
        return 'مرجوع شده';
      case 8:
        return 'لغو شده';
      case 100:
        return 'تحویل شده';
      case 900:
        return 'پیش‌فاکتور';
      case 901:
        return 'تبدیل به فاکتور‌ شده';
      case 444:
        return 'خرید حذف شده';
      case null:
        return 'خرید';
      default:
        return '';
    }
  }

  static IconData cIcon(status) {
    switch (status) {
      case 0:
        return IconsaxPlusLinear.wallet_add;
      case 1:
        return IconsaxPlusLinear.card_send;
      case 2:
        return IconsaxPlusLinear.card_receive;
      default:
        return IconsaxPlusLinear.card_receive;
    }
  }
}
