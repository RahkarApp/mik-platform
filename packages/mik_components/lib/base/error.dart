// ignore_for_file: must_be_immutable, prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_consts/colors.dart';

class ErrorPage extends GetView {
  ErrorPage(this.error, {super.key, required this.onTap});
  var error;
  Function onTap;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          (error.toString() == '' || error.toString() == 'null')
              ? 'خطا در بارگذاری...'
              : error.toString(),
        ),
        MaterialButton(
          onPressed: () => onTap(),
          child: Text('تلاش مجدد', style: TextStyle(color: AppColors.blue)),
        ),
      ],
    );
  }
}

class ErrorSection extends GetView {
  ErrorSection(this.error, {super.key, this.act});
  var error;
  var act;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          (error.toString() == '' || error.toString() == 'null')
              ? 'خطا در بارگذاری...'
              : error,
        ),
        MaterialButton(
          onPressed: act,
          child: Text('تلاش مجدد', style: TextStyle(color: AppColors.blue)),
        ),
      ],
    );
  }
}
