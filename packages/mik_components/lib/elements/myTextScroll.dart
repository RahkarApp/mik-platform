import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:text_scroll/text_scroll.dart';

class MyTextScroll extends GetView {
  String text;
  TextStyle? style;
  MyTextScroll(this.text, {this.style, super.key});
  @override
  Widget build(BuildContext context) {
    return TextScroll(
      text,
      style: style,
      pauseBetween: Duration(seconds: 1),
      velocity: const Velocity(pixelsPerSecond: Offset(40, 0)),
      numberOfReps: 3,
      mode: TextScrollMode.endless,
      intervalSpaces: 10,
      textDirection: TextDirection.rtl,
    );
  }
}
