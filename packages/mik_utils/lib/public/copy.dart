import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';

class Copy {
  static clipdoard(value, {int? size, Color? color}) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        Alert.success('کپی شد.');
      },
      child: Icon(IconsaxPlusLinear.copy, size: size?.toDouble(), color: color),
    );
  }
}
