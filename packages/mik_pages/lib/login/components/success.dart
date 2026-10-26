import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_consts/colors.dart';

class LoginSuccess extends GetView {
  final Future<void> Function() onLogout;
  final String? businessName;
  const LoginSuccess({super.key, required this.onLogout, this.businessName});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                IconsaxPlusLinear.security_safe,
                color: AppColors.primary,
                size: 60,
              ),
              const SizedBox(height: 20),
              const Text(
                'ورود با موفقیت انجام شد.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              if (businessName != null)
                Text(businessName!, textAlign: TextAlign.center),
              BTN(name: 'خروج از حساب', type: BTNType.cancel, onTap: onLogout),
            ],
          ),
        ),
      ),
    ),
  );
}
