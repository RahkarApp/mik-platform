import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/buttons/button.dart';

class RegistrationConfirmation extends GetView {
  final Future<bool> Function() onConfirm;
  final VoidCallback onConditions;
  const RegistrationConfirmation({
    super.key,
    required this.onConfirm,
    required this.onConditions,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('حساب کاربری شما وجود ندارد. برای ثبت‌نام ادامه دهید.'),
      const SizedBox(height: 10),
      const Text(
        'ثبت‌نام در میک به منزله پذیرش شرایط استفاده و قوانین حریم‌خصوصی است.',
      ),
      TextButton(
        onPressed: onConditions,
        child: const Text('شرایط استفاده و حریم‌خصوصی'),
      ),
      const SizedBox(height: 15),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: BTN(
              name: 'تایید و ادامه',
              type: BTNType.ok,
              height: 40,
              navigate: true,
              onTap: () async {
                if (await onConfirm() && context.mounted) {
                  Get.back(result: true);
                }
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: BTN(
              name: 'انصراف',
              type: BTNType.cancel,
              height: 40,
              navigate: true,
              onTap: () => Get.back(result: false),
            ),
          ),
        ],
      ),
    ],
  );
}
