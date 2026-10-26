// ignore_for_file: must_be_immutable, prefer_typing_uninitialized_variables, file_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';

import '../elements/buttons/button.dart';

class DisconnectSocket extends GetView {
  bool tiny;
  double height;
  DisconnectSocket({this.tiny = false, this.height = 70, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tiny ? height : Get.height,
      width: Get.width,
      color: darkMode.isTrue
          ? AppColors.backgroundDarkMode.withValues(alpha: 0.9)
          : AppColors.background.withValues(alpha: 0.9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            IconsaxPlusLinear.link_1,
            size: tiny ? 30 : 90,
            color: AppColors.grey,
          ),
          if (!tiny) const SizedBox(height: 30),
          Text(
            'خطا در اتصال به سرور!!!',
            style: TextStyle(fontSize: tiny ? 13 : 22),
          ),
          if (!tiny) const SizedBox(height: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'برای دسترسی به این قسمت باید به سرور متصل باشید.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: tiny ? 10 : 12),
            ),
          ),
          if (!tiny) const SizedBox(height: 20),
          if (!tiny)
            socketConnected.value == 'disconnect'
                ? BTN(
                    onTap: () async {
                      socketConnected.value = 'error';
                      // SKT.retryConnection();
                    },
                    name: 'ارتباط مجدد با سرور',
                    icon: IconsaxPlusLinear.link_1,
                  )
                : BTN(
                    onTap: () async {
                      socketConnected.value = 'error';
                      // SKT.retryConnection();
                    },
                    name: 'تلاش مجدد',
                    icon: IconsaxPlusLinear.refresh,
                  ),
        ],
      ),
    );
  }
}
