import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_consts/colors.dart';

class MyFAB extends GetView {
  IconData icon;
  String text;
  Color? color;
  Color? itemColor;
  var onTap;
  MyFAB({
    required this.icon,
    required this.text,
    required this.onTap,
    this.color,
    this.itemColor,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      //   constraints: const BoxConstraints(minWidth: 145, maxWidth: 200),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color ?? AppColors.secondary,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: itemColor ?? Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
