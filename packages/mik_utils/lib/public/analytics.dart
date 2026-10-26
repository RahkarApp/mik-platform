// import 'package:appmetrica_plugin/appmetrica_plugin.dart';

// import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// ignore_for_file: deprecated_member_use

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

class Analytics {
  static bool get _supported =>
      !kIsWeb && !Platform.isWindows && !Platform.isLinux;
  static appOpen() async {
    if (!_supported) return;
    await FirebaseAnalytics.instance.logEvent(name: 'app_open');
  }

  static singUp() async {
    if (!_supported) return;
    await FirebaseAnalytics.instance.logEvent(name: 'signUp');
  }

  static login() async {
    if (!_supported) return;
    await FirebaseAnalytics.instance.logEvent(name: 'login');
  }

  static pageView([String? name]) async {
    if (!_supported || name == null) return;
    await FirebaseAnalytics.instance.logScreenView(screenName: name);
  }

  static event(String ev) async {
    if (!_supported) return;
    await FirebaseAnalytics.instance.logEvent(name: ev);
  }

  static catchError(error, page) async {
    if (!_supported) return;
    await FirebaseAnalytics.instance.logEvent(
      name: 'catchError',
      parameters: {'error': error.toString(), 'page': page},
    );
  }
}
