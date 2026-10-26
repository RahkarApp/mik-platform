// ignore_for_file: empty_catches

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:toastification/toastification.dart';

class Alert {
  static success(message, {int? duration, String? desc}) {
    toast(message, ToastificationType.success, duration: duration, desc: desc);
  }

  static info(message, {int? duration, String? desc}) {
    toast(message, ToastificationType.info, duration: duration, desc: desc);
  }

  static warning(message, {int? duration, String? desc}) {
    toast(message, ToastificationType.warning, duration: duration, desc: desc);
  }

  static error(message, {int? duration, String? desc, BuildContext? context}) {
    toast(
      message,
      ToastificationType.error,
      duration: duration,
      desc: desc,
      context: context,
    );
  }

  static notif({
    required title,
    required message,
    ToastificationType? type,
    IconData? icon,
  }) {
    toast(
      title,
      type ?? ToastificationType.info,
      icon: icon,
      duration: 8,
      desc: message,
    );
  }

  static toast(
    String message,
    ToastificationType type, {
    int? duration,
    IconData? icon,
    String? desc,
    BuildContext? context,
  }) {
    toastification.show(
      context: context ?? Get.context,
      type: type,
      style: ToastificationStyle.flatColored,
      title: Text(message, style: TextStyle(fontWeight: FontWeight.w600)),
      description: desc != null ? Text(desc) : null,
      icon: icon != null ? Icon(icon) : null,
      alignment: Alignment.topRight,
      autoCloseDuration: Duration(seconds: duration ?? 3),
      borderRadius: BorderRadius.circular(12.0),
      boxShadow: highModeShadow,
      direction: TextDirection.rtl,
      closeButton: ToastCloseButton(showType: CloseButtonShowType.none),
      closeOnClick: false,
      dragToClose: true,
      applyBlurEffect: true,
    );
  }
}
