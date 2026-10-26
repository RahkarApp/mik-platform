import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_consts/colors.dart';

enum ExpandDirection { up, down, left, right }

class MultiFabItem {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final Color? color;
  final Color? itemColor;
  final bool? borderOnly;

  MultiFabItem({
    required this.icon,
    required this.text,
    required this.onTap,
    this.color,
    this.itemColor,
    this.borderOnly = false,
  });
}

class MyMultiFAB extends StatefulWidget {
  final IconData mainIcon;
  final String? mainText;
  final Color? mainColor;
  final Color? mainItemColor;
  final List<MultiFabItem> items;
  final ExpandDirection direction;
  final double spacing;
  final bool? borderOnly;

  const MyMultiFAB({
    super.key,
    required this.mainIcon,
    this.mainText,
    this.mainColor,
    this.mainItemColor,
    required this.items,
    this.direction = ExpandDirection.up,
    this.spacing = 50,
    this.borderOnly = false,
  });

  @override
  State<MyMultiFAB> createState() => _MyMultiFABState();
}

class _MyMultiFABController extends GetxController {
  bool _isExpanded = false;
}

class _MyMultiFABState extends State<MyMultiFAB>
    with SingleTickerProviderStateMixin {
  late final _page = _MyMultiFABController();

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    {
      _page._isExpanded = !_page._isExpanded;
      if (_page._isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
      _page.update();
    }
  }

  Offset _getItemOffset(int index) {
    final spacing = widget.spacing;
    switch (widget.direction) {
      case ExpandDirection.up:
        return Offset(0, -(spacing * (index + 1)));
      case ExpandDirection.down:
        return Offset(0, spacing * (index + 1));
      case ExpandDirection.left:
        return Offset(-(spacing * (index + 1)), 0);
      case ExpandDirection.right:
        return Offset(spacing * (index + 1), 0);
    }
  }

  double _getItemRightOffset(int index, double animationValue) {
    final offset = _getItemOffset(index);
    if (widget.direction == ExpandDirection.right) {
      return offset.dx * animationValue;
    } else if (widget.direction == ExpandDirection.left) {
      return -offset.dx * animationValue;
    }
    return 0;
  }

  double _getItemTopOffset(int index, double animationValue) {
    final offset = _getItemOffset(index);
    if (widget.direction == ExpandDirection.down) {
      return -(offset.dy * animationValue);
    } else if (widget.direction == ExpandDirection.up) {
      return -(offset.dy * animationValue);
    }
    return 0;
  }

  Widget _buildItemButton(MultiFabItem item, int index) {
    final offset = _getItemOffset(index);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final animationValue = _animation.value;
        return Positioned(
          right: 0, // _getItemRightOffset(index, animationValue),
          bottom: _getItemTopOffset(index, animationValue),
          child: Opacity(
            opacity: animationValue,
            child: Transform.scale(
              scale: animationValue,
              child: IgnorePointer(
                ignoring: animationValue == 0,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {
                      print('object');
                      _toggleExpansion();
                      item.onTap();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: (item.borderOnly ?? false)
                            ? Colors.transparent
                            : item.color ?? AppColors.secondary,
                        border: (item.borderOnly ?? false)
                            ? Border.all(
                                color: item.color ?? AppColors.secondary,
                              )
                            : null,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              color: (item.borderOnly ?? false)
                                  ? (item.itemColor ?? AppColors.secondary)
                                  : (item.itemColor ?? Colors.white),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              item.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: (item.borderOnly ?? false)
                                    ? (item.itemColor ?? AppColors.secondary)
                                    : (item.itemColor ?? Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainButton() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final mainColor =
            Color.lerp(
              widget.mainColor ?? AppColors.secondary,
              AppColors.disable,
              _animation.value,
            ) ??
            AppColors.disable;

        return InkWell(
          onTap: _toggleExpansion,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: (widget.borderOnly ?? false)
                  ? Colors.transparent
                  : mainColor,
              border: (widget.borderOnly ?? false)
                  ? Border.all(color: mainColor)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: _page._isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    widget.mainIcon,
                    color: (widget.borderOnly ?? false)
                        ? (widget.mainItemColor ?? AppColors.secondary)
                        : (widget.mainItemColor ?? Colors.white),
                  ),
                ),
                if (widget.mainText != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    widget.mainText!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (widget.borderOnly ?? false)
                          ? (widget.mainItemColor ?? AppColors.secondary)
                          : (widget.mainItemColor ?? Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_MyMultiFABController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        // محاسبه حداکثر ارتفاع و عرض مورد نیاز برای دکمه‌های فرعی
        double maxHeight = 100; // حداقل ارتفاع برای دکمه اصلی
        double maxWidth = 200; // حداقل عرض برای دکمه‌ها

        if (widget.direction == ExpandDirection.up ||
            widget.direction == ExpandDirection.down) {
          maxHeight = (widget.items.length * widget.spacing) + 100;
        } else if (widget.direction == ExpandDirection.left ||
            widget.direction == ExpandDirection.right) {
          maxWidth = (widget.items.length * widget.spacing) + 200;
        }

        return SizedBox(
          width: Get.width,
          height: Get.height,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topRight,
            children: [
              // دکمه اصلی (قبل از دکمه‌های فرعی)
              Positioned(right: 0, bottom: 0, child: _buildMainButton()),
              // دکمه‌های فرعی (بعد از دکمه اصلی تا روی آن قرار بگیرند)
              ...widget.items.asMap().entries.map((entry) {
                return _buildItemButton(entry.value, entry.key);
              }),
            ],
          ),
        );
      },
    );
  }
}
