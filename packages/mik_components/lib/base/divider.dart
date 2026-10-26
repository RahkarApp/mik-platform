import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';

class MyDivider extends GetView {
  String? text;
  Color? color;
  String? entText;
  double? indent;
  double? endIndent;
  bool? require;
  bool? bold;
  MyDivider({
    this.text,
    this.color,
    this.entText,
    this.endIndent,
    this.indent,
    this.require,
    this.bold,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5, top: 5),
      alignment: Alignment.center,
      child: Row(
        children: [
          if (text != null)
            Container(
              padding: const EdgeInsets.only(right: 10, left: 5),
              child: Row(
                children: [
                  Text(
                    text!,
                    style: TextStyle(
                      fontWeight: bold == false
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  if (require == true)
                    Text(
                      ' *',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          Flexible(
            child: Divider(
              thickness: 1,
              indent: indent,
              endIndent: endIndent,
              color: darkMode.isTrue
                  ? Colors.grey.shade600
                  : Colors.grey.shade300,
            ),
          ),
          if (entText != null)
            Container(
              padding: const EdgeInsets.only(right: 5, left: 10),
              child: Text(entText!),
            ),
        ],
      ),
    );
  }
}
