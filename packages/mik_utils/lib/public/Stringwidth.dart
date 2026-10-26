import 'package:flutter/material.dart';

class StringChecker {
  static double width(text) {
    return (TextPainter(
            text: TextSpan(
                text: text,
                style: TextStyle(fontSize: text.length > 10 ? 19 : 21)),
            maxLines: 1,
            textDirection: TextDirection.ltr)
          ..layout())
        .size
        .width;
  }
}
