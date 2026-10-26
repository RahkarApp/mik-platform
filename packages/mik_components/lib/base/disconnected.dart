// ignore_for_file: must_be_immutable, prefer_typing_uninitialized_variables, file_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';

class Disconnected extends GetView {
  var callback;
  Disconnected({this.callback, super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        height: Get.height,
        width: Get.width,
        color: AppColors.background,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            internetCheck.isFalse
                ? const Icon(IconsaxPlusLinear.wifi)
                : serverConnect.value == 'error'
                ? Icon(IconsaxPlusLinear.cloud_remove, size: 50)
                : Container(),
            Text(
              internetCheck.isFalse
                  ? 'اینترنت قطع شده!!!'
                  : serverConnect.value == 'error'
                  ? 'اتصال به سرور قطع شده'
                  : 'اینترنت قطع شده!!!',
              style: const TextStyle(fontSize: 25),
            ),
            Text(
              internetCheck.isFalse
                  ? 'برای دسترسی به این قسمت باید به اینترنت متصل باشید.'
                  : serverConnect.value == 'error'
                  ? 'برای اتصال به این قسمت باید به سرور متصل باشید'
                  : 'برای دسترسی به این قسمت باید به اینترنت متصل باشید.',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              internetCheck.isFalse
                  ? ''
                  : serverConnect.value == 'error'
                  ? 'دقایقی دیگر تلاش کنید، در صورت بروز مشکل با پشتیبانی تماس بگیرید'
                  : '',
            ),
            const SizedBox(height: 20),
            if (callback != null)
              InkWell(
                onTap: () => callback(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    // color: green,
                    // border: Border.all(),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(IconsaxPlusLinear.refresh, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'بررسی مجدد',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
