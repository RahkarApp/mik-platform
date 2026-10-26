// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

bool isColorDark(Color color) {
  // فرمول روشنایی استاندارد برای رنگ‌ها
  double brightness =
      ((color.red * 299 + color.green * 587 + color.blue * 114) / 1000) /
          color.opacity;
  return brightness < 128; // اگر کم باشد یعنی رنگ تیره است
}
