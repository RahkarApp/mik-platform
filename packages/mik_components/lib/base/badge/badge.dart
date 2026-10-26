// ignore_for_file: must_be_immutable, library_private_types_in_public_api

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mik_consts/colors.dart';
part 'indicatorPainter.dart';

/// BallScale.
class MyBadge extends StatefulWidget {
  int? count;
  MyBadge({super.key, this.count});

  @override
  _MyBadgeState createState() => _MyBadgeState();
}

class _MyBadgeState extends State<MyBadge> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _scaleAnimation = Tween(begin: 1.0, end: 3.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _opacityAnimation = ReverseAnimation(_scaleAnimation);
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        FadeTransition(
          opacity: _opacityAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: const IndicatorShapeWidget(shape: Shape.circle),
          ),
        ),
        CircleAvatar(
          backgroundColor: AppColors.secondary,
          radius: widget.count != null ? 8 : 5,
          child: widget.count != null
              ? Text(
                  widget.count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1,
                  ),
                )
              : Container(),
        ),
      ],
    );
  }
}
