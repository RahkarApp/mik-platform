import 'package:get/get.dart';
// ignore_for_file: library_private_types_in_public_api

import "package:flutter/material.dart";

import 'dart:math';

import 'package:mik_consts/colors.dart';

class Loader extends StatefulWidget {
  final double radius;
  final double dotRadius;

  const Loader({super.key, this.radius = 25.0, this.dotRadius = 13.0});

  @override
  _LoaderState createState() => _LoaderState();
}

class _LoaderController extends GetxController {
  late double radius;
  late double dotRadius;
}

class _LoaderState extends State<Loader> with SingleTickerProviderStateMixin {
  late final _page = _LoaderController();

  // ignore: non_constant_identifier_names
  late Animation<double> animation_rotation;
  // ignore: non_constant_identifier_names
  late Animation<double> animation_radius_in;
  // ignore: non_constant_identifier_names
  late Animation<double> animation_radius_out;
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    _page.radius = widget.radius;
    _page.dotRadius = widget.dotRadius;

    controller = AnimationController(
      lowerBound: 0.0,
      upperBound: 1.0,
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    animation_rotation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 1.0, curve: Curves.linear),
      ),
    );

    animation_radius_in = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.75, 1.0, curve: Curves.elasticIn),
      ),
    );

    animation_radius_out = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.25, curve: Curves.elasticOut),
      ),
    );

    controller.addListener(() {
      {
        if (controller.value >= 0.75 && controller.value <= 1.0) {
          _page.radius = widget.radius * animation_radius_in.value;
        } else if (controller.value >= 0.0 && controller.value <= 0.25) {
          _page.radius = widget.radius * animation_radius_out.value;
        }
        _page.update();
      }
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {}
    });

    controller.repeat();

    print('animation controller init');
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_LoaderController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        return Container(
          width: 100.0,
          height: 100.0,
          //color: Colors.black12,
          alignment: Alignment.center,
          child: Center(
            child: RotationTransition(
              turns: animation_rotation,
              child: Center(
                child: Stack(
                  children: <Widget>[
                    Transform.translate(
                      offset: const Offset(0.0, 0.0),
                      child: Dot(radius: _page.radius, color: Colors.black12),
                    ),
                    Transform.translate(
                      offset: Offset(
                        _page.radius * cos(0.0),
                        _page.radius * sin(0.0),
                      ),
                      child: Dot(
                        radius: _page.dotRadius,
                        color: AppColors.blue,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(
                        _page.radius * cos(0.0 + 1 * pi / 5),
                        _page.radius * sin(0.0 + 1 * pi / 5),
                      ),
                      child: Dot(
                        radius: _page.dotRadius,
                        color: AppColors.secondary,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(
                        _page.radius * cos(0.0 + 2 * pi / 5),
                        _page.radius * sin(0.0 + 2 * pi / 5),
                      ),
                      child: Dot(
                        radius: _page.dotRadius,
                        color: AppColors.primary,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(
                        _page.radius * cos(0.0 + 3 * pi / 5),
                        _page.radius * sin(0.0 + 3 * pi / 5),
                      ),
                      child: Dot(
                        radius: _page.dotRadius,
                        color: AppColors.yellow,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(
                        _page.radius * cos(0.0 + 4 * pi / 5),
                        _page.radius * sin(0.0 + 4 * pi / 5),
                      ),
                      child: Dot(
                        radius: _page.dotRadius,
                        color: AppColors.success,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(
                        _page.radius * cos(0.0 + 5 * pi / 5),
                        _page.radius * sin(0.0 + 5 * pi / 5),
                      ),
                      child: Dot(
                        radius: _page.dotRadius,
                        color: AppColors.blue,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(
                        _page.radius * cos(0.0 + 6 * pi / 5),
                        _page.radius * sin(0.0 + 6 * pi / 5),
                      ),
                      child: Dot(
                        radius: _page.dotRadius,
                        color: AppColors.secondary,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(
                        _page.radius * cos(0.0 + 7 * pi / 5),
                        _page.radius * sin(0.0 + 7 * pi / 5),
                      ),
                      child: Dot(
                        radius: _page.dotRadius,
                        color: AppColors.primary,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(
                        _page.radius * cos(0.0 + 8 * pi / 5),
                        _page.radius * sin(0.0 + 8 * pi / 5),
                      ),
                      child: Dot(
                        radius: _page.dotRadius,
                        color: AppColors.yellow,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(
                        _page.radius * cos(0.0 + 9 * pi / 5),
                        _page.radius * sin(0.0 + 9 * pi / 5),
                      ),
                      child: Dot(
                        radius: _page.dotRadius,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    print('animation controller dispose');
    super.dispose();
  }
}

class Dot extends StatelessWidget {
  final double? radius;
  final Color? color;

  const Dot({super.key, this.radius, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: radius,
        height: radius,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
