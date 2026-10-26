// ignore_for_file: file_names

import 'package:mik_data/utils/variable.dart';


class SMSPattern {
  static check(orderType) {
    for (var i = 0; i < pattern.length; i++) {
      var itPT = pattern.getAt(i)!;
      if (itPT.orderType == orderType && itPT.active!) {
        return true;
      }
    }
    return false;
  }

  static String findNameByOrderType(orderType) {
    switch (orderType) {
      case 1:
        return 'پیامک ثبت سفارش';
      case 2:
        return 'پیامک سفارش آماده ارسال';
      case 3:
        return 'پیامک سفارش ارسال شده';
      case 4:
        return 'پیامک تشکر از خرید با تاخیر';
      case 8:
        return 'پیامک سفارش لغو شده';
      case 9:
        return 'پیامک سفارش مرجوع شده';
      case 100:
        return 'پیامک تایید پرداخت آنلاین';
      case 900:
        return 'پیامک ثبت پیش‌فاکتور';
      default:
        return '';
    }
  }

  static int findOrderTypeByName(name) {
    switch (name) {
      case 'پیامک ثبت سفارش':
        return 1;
      case 'پیامک سفارش آماده ارسال':
        return 2;
      case 'پیامک سفارش ارسال شده':
        return 3;
      case 'پیامک تشکر از خرید با تاخیر':
        return 4;
      case 'پیامک سفارش لغو شده':
        return 8;
      case 'پیامک سفارش مرجوع شده':
        return 9;
      case 'پیامک تایید پرداخت آنلاین':
        return 100;
      case 'پیامک ثبت پیش‌فاکتور':
        return 900;
      default:
        return 0;
    }
  }

  static findByCode(pCode) {
    for (var i = 0; i < pattern.length; i++) {
      var element = pattern.getAt(i)!;
      if (element.code == pCode) {
        switch (element.orderType) {
          case 1:
            return {"name": 'پیامک ثبت سفارش', "orderType": 1};
          case 2:
            return {"name": 'پیامک سفارش آماده ارسال', "orderType": 2};
          case 3:
            return {"name": 'پیامک سفارش ارسال شده', "orderType": 3};
          case 4:
            return {"name": 'پیامک تشکر از خرید با تاخیر', "orderType": 4};
          case 8:
            return {"name": 'پیامک سفارش لغو شده', "orderType": 8};
          case 9:
            return {"name": 'پیامک سفارش مرجوع شده', "orderType": 9};
          case 100:
            return {"name": 'پیامک تایید پرداخت آنلاین', "orderType": 100};
          case 900:
            return {"name": 'پیامک ثبت پیش‌فاکتور', "orderType": 900};
          default:
            return {"name": '', "orderType": 1};
        }
      }
    }
    return {"name": '', "orderType": 0};
  }
}
