import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_utils/public/startup.dart';

class StartupController extends GetxController {
  final Future<void> Function() prepare;
  final Future<void> Function() readDatabase;
  final Future<void> Function() readSettings;
  final Future<void> Function(BuildContext context, String? to) openApp;
  final Future<void> Function()? onAppOpened;
  final RxBool loading = true.obs;
  final RxBool failed = false.obs;
  bool _running = false;
  bool _closed = false;
  bool _recorded = false;

  StartupController({
    required this.prepare,
    required this.readDatabase,
    required this.readSettings,
    required this.openApp,
    this.onAppOpened,
  });

  Future<void> start(BuildContext context, {String? to}) async {
    if (_running || _closed || !context.mounted) return;
    _running = true;
    loading.value = true;
    failed.value = false;
    try {
      await prepare();
      if (_closed || !context.mounted) return;
      await readDatabase();
      if (_closed || !context.mounted) return;
      await readSettings();
      if (_closed || !context.mounted) return;
      await openApp(context, StartupFX.initialRoute(to));
    } catch (error) {
      debugPrint('Startup failed: ${error.runtimeType}');
      if (!_closed && context.mounted) failed.value = true;
    } finally {
      _running = false;
      if (!_closed) loading.value = false;
    }
  }

  Future<void> recordAppOpened() async {
    if (_recorded || _closed) return;
    _recorded = true;
    try {
      await onAppOpened?.call();
    } catch (error) {
      debugPrint('Startup analytics unavailable: ${error.runtimeType}');
    }
  }

  @override
  void onClose() {
    _closed = true;
    super.onClose();
  }
}
