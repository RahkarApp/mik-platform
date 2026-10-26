import 'dart:convert';

import 'package:flutter/services.dart';

class Convertor {
  static String numToStr(n) {
    var nn = n.toString().split('.');
    if (nn.length > 1 && (int.tryParse(nn[1]) ?? 0) > 0) {
      return n.toString();
    } else {
      return nn[0].toString();
    }
  }

  static String base64String(Uint8List data) {
    return base64Encode(data);
  }
}
