import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_consts/colors.dart';

class AlertBox {
  static success({
    required String title,
    required List<Widget> children,
    bool dismissable = false,
    double? height,
  }) {
    return t(
      children: children,
      title: title,
      dismissable: dismissable,
      color: AppColors.success,
      icon: IconsaxPlusLinear.tick_circle,
      height: height,
    );
  }

  static info({
    required String title,
    required List<Widget> children,
    bool dismissable = false,
    double? height,
  }) {
    return t(
      children: children,
      title: title,
      dismissable: dismissable,
      color: AppColors.blue,
      icon: IconsaxPlusLinear.info_circle,
      height: height,
    );
  }

  static warning({
    required String title,
    required List<Widget> children,
    bool dismissable = false,
    double? height,
  }) {
    return t(
      children: children,
      title: title,
      dismissable: dismissable,
      color: AppColors.yellow,
      icon: IconsaxPlusLinear.danger,
      height: height,
    );
  }

  static error({
    required String title,
    required List<Widget> children,
    bool dismissable = false,
    double? height,
  }) {
    return t(
      children: children,
      title: title,
      dismissable: dismissable,
      color: AppColors.error,
      icon: IconsaxPlusLinear.close_circle,
      height: height,
    );
  }

  static t({
    required List<Widget> children,
    required String title,
    required bool dismissable,
    required Color color,
    required IconData icon,
    double? height,
  }) {
    RxBool close = false.obs;

    GlobalKey key = GlobalKey();
    return Obx(
      () => AnimatedContainer(
        margin: EdgeInsets.only(top: 5, bottom: 5),
        duration: Duration(milliseconds: 500),
        height: close.isFalse ? (height ?? 100) : 0,
        width: Get.width,
        child: Container(
          width: Get.width,
          key: key,
          decoration: BoxDecoration(
            border: Border.all(
              color: close.isFalse ? color : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: 0.3),
          ),
          child: Column(
            children: [
              Container(
                alignment: Alignment.topLeft,
                margin: EdgeInsets.only(left: 3, top: 3, right: 3),
                child: Row(
                  children: [
                    Flexible(
                      fit: FlexFit.tight,
                      child: Row(
                        spacing: 5,
                        children: [
                          Icon(icon),
                          Text(
                            title,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    if (dismissable)
                      InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: () {
                          close.value = true;
                        },
                        child: Icon(
                          IconsaxPlusLinear.close_circle,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
