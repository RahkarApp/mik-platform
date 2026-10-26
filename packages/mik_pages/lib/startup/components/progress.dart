import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/linearProgress.dart';
import 'package:mik_consts/colors.dart';

class StartupProgress extends GetView {
  final RxBool updating;
  final RxDouble current;
  final RxDouble total;

  const StartupProgress({
    super.key,
    required this.updating,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) => Obx(
    () => updating.isFalse
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                const Text(
                  'درحال بروزرسانی دیتابیس و آماده‌سازی اطلاعات برنامه',
                ),
                MyLinearProgress(
                  colors: AppColors.primary,
                  value: total.value > 0
                      ? (current.value / total.value).clamp(0.0, 1.0)
                      : 0,
                ),
                const Text('لطفا تا پایان عملیات منتظر بمانید...'),
              ],
            ),
          ),
  );
}
