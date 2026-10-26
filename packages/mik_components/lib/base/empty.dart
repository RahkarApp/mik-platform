// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_variables/variable.dart';

class EmptyList extends GetView {
  IconData? icon;
  Color? iconColor, textColor;
  String text;
  double? textSize;
  double? emojiSize;
  double? iconSize;
  String? emoji;
  String? desc;
  Widget? child;
  EmptyList({
    super.key,
    this.icon,
    this.iconColor,
    this.textColor,
    this.emoji,
    this.emojiSize,
    this.iconSize,
    this.textSize,
    required this.text,
    this.desc,
    this.child,
  });
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (emoji == null)
              Icon(
                icon,
                size:
                    iconSize ??
                    (Responsive.isMobile(context) ? Get.width / 5 : 100),
                color:
                    iconColor ??
                    (darkMode.isTrue ? Colors.white38 : Colors.black26),
              ),
            if (emoji != null)
              Text(emoji!, style: TextStyle(fontSize: emojiSize ?? 90)),
            const SizedBox(height: 15),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: textSize ?? 20,
                color:
                    textColor ??
                    (darkMode.isTrue ? Colors.white38 : Colors.black45),
              ),
            ),
            if (desc != null)
              Container(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  desc!,
                  style: TextStyle(
                    color: darkMode.isTrue ? Colors.white38 : Colors.black45,
                  ),
                ),
              ),
            Container(
              margin: child != null ? EdgeInsets.only(top: 20) : null,
              child: child ?? Container(),
            ),
          ],
        ),
      ),
    );
  }
}
