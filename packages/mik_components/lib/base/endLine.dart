import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_variables/variable.dart';

// ignore: must_be_immutable
class EndLine extends GetView {
  bool? show = true;
  double? rightPadding;

  ///0 = fully transparent, 1 = fully opaque
  double? opacity;
  EndLine({super.key, this.show, this.rightPadding, this.opacity});
  @override
  Widget build(BuildContext context) {
    return show == null || (show != null && show!)
        ? Container(
            height: 1,
            width: Get.width,
            margin: EdgeInsets.only(right: rightPadding ?? 60),
            color:
                (darkMode.isTrue ? Colors.grey.shade600 : Colors.grey.shade300)
                    .withValues(alpha: opacity ?? 1),
          )
        : Container();
  }
}
