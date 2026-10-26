import '../variable.dart';

class SMSFX {
  static patternFindByCode(pCode) {
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
