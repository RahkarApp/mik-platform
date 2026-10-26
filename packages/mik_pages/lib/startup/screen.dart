import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_consts/colors.dart';
import 'package:widget_loading/widget_loading.dart';

import 'components/error.dart';
import 'components/progress.dart';
import 'controller.dart';

class StartupScreen extends StatefulWidget {
  final String? to;
  final StartupController Function() createController;
  final RxBool updating;
  final RxDouble updateCurrent;
  final RxDouble updateTotal;

  const StartupScreen({
    super.key,
    this.to,
    required this.createController,
    required this.updating,
    required this.updateCurrent,
    required this.updateTotal,
  });

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late final StartupController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.createController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller.recordAppOpened());
      unawaited(_controller.start(context, to: widget.to));
    });
  }

  @override
  void dispose() {
    _controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                StartupProgress(
                  updating: widget.updating,
                  current: widget.updateCurrent,
                  total: widget.updateTotal,
                ),
                Image.asset(
                  'packages/mik_pages/assets/images/logo/logo.png',
                  width: 70,
                ),
                const SizedBox(height: 30),
                const Text('RahkarApp.ir', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          Obx(
            () => _controller.failed.isTrue
                ? StartupError(
                    onRetry: () => _controller.start(context, to: widget.to),
                  )
                : CircularWidgetLoading(
                    padding: const EdgeInsets.only(top: 250),
                    loading: _controller.loading.value,
                    dotRadius: 3,
                    maxLoadingCircleSize: 30,
                    dotColor: AppColors.primary,
                    child: const SizedBox.shrink(),
                  ),
          ),
        ],
      ),
    ),
  );
}
