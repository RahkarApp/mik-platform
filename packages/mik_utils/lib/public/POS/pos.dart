import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_variables/variable.dart';
import 'package:universal_io/io.dart';

enum PosModel { undetected, i9000S, p10, p3, a8900 }

class PosBrand {
  static const String SEP = 'sep'; // سپ

  static const String PNA = 'pna'; //پرداخت نوثن

  static const String BPM = 'bpm'; // به پرداخت ملت
}

class POSFX {
  static isPos() {
    if (detect() != PosModel.undetected) {
      return true;
    }
    return false;
  }

  static PosModel detect() {
    if (!kIsWeb) {
      if (Platform.isAndroid &&
          device!.data['product'] == 'i9000S' &&
          device!.data['model'] == 'i9000S') {
        return PosModel.i9000S;
      } else if (Platform.isAndroid &&
          device!.data['product'] == 'D1' &&
          device!.data['model'] == 'P3') {
        return PosModel.p3;
      } else if (Platform.isAndroid &&
          device!.data['model'] == 'P10' &&
          device!.data['product'] == 'D1') {
        return PosModel.p10;
      } else if (Platform.isAndroid &&
          device!.data['model'] == 'A8900' &&
          device!.data['product'] == 'A8900') {
        return PosModel.a8900;
      }
    }
    return PosModel.undetected;
  }

  static brandPOS() {
    const posBrand = String.fromEnvironment('PSP');
    print('pos brand is $posBrand');
    return posBrand;
  }

  static bool isCardOK(response) {
    if (response == null) {
      Alert.warning('خطا در انجام تراکنش');
      return false;
    }
    late var res;
    if (kDebugMode) {
      res = response;
    } else {
      res = jsonDecode(response);
    }
    if (brandPOS() == PosBrand.PNA) {
      if (res["Status"] == "OK") {
        return true;
      } else if (res["Status"] == "ERROR") {
        switch (res["ResponseCode"]) {
          case "201":
            Alert.warning('زمان انجام تراکنش به پایان رسیده است');
            return false;

          default:
            Alert.warning('خطا در انجام تراکنش: ${res["ResponseCode"]}');
            return false;
        }
      }
    } else if (brandPOS() == PosBrand.SEP) {
      if (response is! String || response.isEmpty) {
        Alert.warning('پاسخ نامعتبر از دستگاه کارتخوان');
        return false;
      }

      final parts = response.split('|');

      // حداقل باید status وجود داشته باشد
      if (parts.isEmpty) {
        Alert.warning('پاسخ نامعتبر از دستگاه کارتخوان');
        return false;
      }

      final status = parts[0].trim();

      /// طبق تجربه عملی TechPay:
      /// 0 یا SUCCESS = موفق
      if (status == "0" || status.toUpperCase() == "SUCCESS") {
        return true;
      }

      // پیام خطا (اگر وجود داشته باشد)
      final errorMessage = (parts.length > 4 && parts[4].trim().isNotEmpty)
          ? parts[4]
          : 'تراکنش ناموفق است';
      Alert.warning(errorMessage);
      return false;
    }
    // ========================= BPM (به پرداخت ملت) =========================
    else if (brandPOS() == PosBrand.BPM) {
      try {
        if (res['responseCode'] == '000') {
          return true;
        }

        // final resultCode = res["resultCode"]?.toString();

        // if (resultCode == "000" || resultCode == "0") {
        //   return true;
        // }

        Alert.error(response);
        return false;
      } catch (e) {
        Alert.warning('پاسخ نامعتبر از دستگاه کارتخوان');
        return false;
      }
    }

    return false;
  }
}
