import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_consts/colors.dart';

import 'package:mik_components/elements/side/side.dart';

class EndItem extends StatelessWidget {
  const EndItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 1,
      width: Responsive.getWidth(context),
      color: Colors.white.withOpacity(0.18),
    );
  }
}

// ignore: must_be_immutable

class Item extends StatelessWidget {
  final IconData icon;
  final String text;
  final int index;
  final void Function()? onTap;

  const Item({
    super.key,
    required this.icon,
    required this.text,
    required this.index,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap:
          onTap ??
          () {
            if (selectItem.value == index) {
              if (Responsive.isTablet(context)) selectItem.value = 0;
            } else {
              selectItem.value = index;
            }
          },
      child: Obx(() {
        final bool isSelected = selectItem.value == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(top: 6),
          height: 78,
          width: 78,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? Colors.white.withOpacity(0.16)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.35)
                  : Colors.white.withOpacity(0.08),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: isSelected ? 36 : 24,
                height: isSelected ? 36 : 24,
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isSelected ? 34 : 22,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  text,
                  key: ValueKey(isSelected),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: isSelected ? 1 : 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
