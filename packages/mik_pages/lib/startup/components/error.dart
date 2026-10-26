import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/buttons/button.dart';

class StartupError extends GetView {
  final Future<void> Function() onRetry;
  const StartupError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('راه‌اندازی برنامه انجام نشد.'),
          const SizedBox(height: 12),
          BTN(name: 'تلاش دوباره', onTap: onRetry),
        ],
      ),
    ),
  );
}
