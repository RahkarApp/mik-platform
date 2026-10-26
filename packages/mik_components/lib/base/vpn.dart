import 'package:mik_variables/variable.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_consts/colors.dart';

class VPNPage extends GetView {
  const VPNPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height,
      width: Get.width,
      color: AppColors.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            IconsaxPlusLinear.shield_security,
            size: 50,
            color: (darkMode.value
                ? AppColors.background
                : AppColors.backgroundDarkMode),
          ),
          Text(
            'VPN خود را خاموش کنید!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: (darkMode.value
                  ? AppColors.background
                  : AppColors.backgroundDarkMode),
            ),
          ),
        ],
      ),
    );
  }
}
