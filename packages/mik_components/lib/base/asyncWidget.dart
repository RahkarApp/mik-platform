// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/error.dart';
import 'package:mik_consts/colors.dart';
import 'package:widget_loading/widget_loading.dart';

typedef RenderSuccessCallback = Widget Function(dynamic data);
typedef InitStateCallback = Future<Object> Function();

enum LoadingState { Error, Loading, Success }

class AsyncWidget extends GetView {
  AsyncWidget({
    super.key,
    required this.child,
    required this.initState,
    this.loadingDuration,
    this.loaderColor,
  });
  RenderSuccessCallback child;
  InitStateCallback initState;
  Color? loaderColor;
  int? loadingDuration;
  final Rx<LoadingState> _loadingState = LoadingState.Loading.obs;
  dynamic _data;
  dynamic _error;
  _initState() async {
    _loadingState.value = LoadingState.Loading;
    try {
      var data = await initState();
      _data = data;
      _loadingState.value = LoadingState.Success;
    } catch (e) {
      _error = e;
      _data = null;
      _loadingState.value = LoadingState.Error;
    }
  }

  @override
  Widget build(BuildContext context) {
    _initState();
    return Obx(
      () => (_loadingState.value == LoadingState.Error)
          ? ErrorSection(_error.toString(), act: () => _initState())
          : CircularWidgetLoading(
              loading: _loadingState.value == LoadingState.Loading,
              dotRadius: 2,
              maxLoadingCircleSize: 30,
              loadingDuration: Duration(milliseconds: loadingDuration ?? 50),
              appearingDuration: const Duration(milliseconds: 500),
              dotColor: loaderColor ?? AppColors.primary,
              child: Obx(
                () => _loadingState.value == LoadingState.Success
                    ? child(_data)
                    : Container(),
              ),
            ),
    );
  }
}
