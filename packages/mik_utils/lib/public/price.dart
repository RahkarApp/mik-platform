// ignore_for_file: unused_element

import 'package:mik_utils/public/number.dart';
import 'package:mik_variables/variable.dart';
import 'package:persian_tools/persian_tools.dart';


class Price {
  static String show(num v) {
    if (currencyType == 0) {
      v = v * 10;
    }
    try {
      return Number.addCommas(int.parse(v.toStringAsFixed(0)));
    } catch (e) {
      return addCommas(v.toStringAsFixed(0));
    }
  }

  static int toInt(String v) {
    return int.tryParse(v.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
  }

  static String showWithCurrency(num v) {
    return '${Number.addCommas(int.parse(v.toStringAsFixed(0)))} ${currency()}';
  }

  static String showWithCurrencyMini(num v) {
    return '${Number.addCommas(int.parse(v.toStringAsFixed(0)))} ${currency().substring(0, 1)}';
  }

  static num sepPrice(num price) {
    if (price > 1000000) {
      price = price / 1000000;
    } else if (price > 1000) {
      price = price / 1000;
    }
    return num.parse((price).toStringAsFixed(2));
  }

  static String sepPriceCurrency(num price) {
    if (price > 1000000) {
      return 'میلیون تومان';
    } else if (price > 1000) {
      return 'هزار تومان';
    }
    return currency();
  }

  static String currency() {
    if (currencyType == 0) {
      return 'ریال';
    }
    return 'تومان';
  }
}
