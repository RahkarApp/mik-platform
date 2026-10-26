// ignore_for_file: must_be_immutable, file_names, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_utils/public/number.dart';

import 'package:mik_consts/colors.dart';

class MyLinearProgress extends GetView {
  double value;
  Color colors;
  MyLinearProgress({super.key, required this.value, required this.colors});
  @override
  Widget build(BuildContext context) {
    if (value > 1) value = 1;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 20,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              color: colors,
              value: value <= 1 ? value : 1,
            ),
          ),
          Container(
            alignment: Alignment.topCenter,
            child: Text(
              '${Number.addCommas(double.parse((value <= 1 ? (value * 100).toStringAsFixed(2) : 100).toString()))}%',
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
