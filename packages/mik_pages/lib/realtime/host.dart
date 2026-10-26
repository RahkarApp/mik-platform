import 'package:get/get.dart';

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/realtime.dart';

/// The app shell owns the connection; dashboard listeners only rebuild their content.
class BusinessRealtimeHost extends StatefulWidget {
  final String appId;
  final WidgetBuilder builder;
  final bool manageConnection;
  const BusinessRealtimeHost({
    required this.appId,
    required this.builder,
    this.manageConnection = true,
    super.key,
  });
  @override
  State<BusinessRealtimeHost> createState() => _BusinessRealtimeHostState();
}

class _BusinessRealtimeHostController extends GetxController {
  RealtimeFX? client;
  StreamSubscription<RealtimeUpdate>? subscription;
  StreamSubscription<String>? contextChanges;
  String? branchId;
}

class _BusinessRealtimeHostState extends State<BusinessRealtimeHost>
    with WidgetsBindingObserver {
  late final _page = _BusinessRealtimeHostController();

  @override
  void initState() {
    super.initState();
    if (widget.manageConnection) WidgetsBinding.instance.addObserver(this);
    _page.contextChanges = BusinessContext.changes.listen((appId) {
      if (mounted && appId == widget.appId) bind();
    });
    bind();
  }

  void bind() {
    final active = BusinessContext.forApp(widget.appId);
    final selected = active?.selectedBranch?.branchId;
    if (identical(_page.client?.context, active) && _page.branchId == selected)
      return;
    _page.subscription?.cancel();
    _page.subscription = null;
    if (widget.manageConnection) _page.client?.stop();
    _page.client = null;
    _page.branchId = selected;
    if (active == null || selected == null) return;
    _page.client = RealtimeFX.forContext(active);
    _page.subscription = _page.client!.updates.listen((update) {
      if (!mounted) return;
      if (update.resync) {
        _page.update();
      }
      if (update.failure == null || !widget.manageConnection) return;
      Alert.error(
        update.resync
            ? 'دریافت مجدد اطلاعات و مجوزها انجام نشد؛ اطلاعات را تازه کنید.'
            : 'ارتباط دریافت تغییرات قطع شد؛ اتصال دوباره تلاش می‌شود. برای اطلاعات تازه می‌توانید صفحه را تازه کنید.',
      );
    });
    if (widget.manageConnection) unawaited(_page.client!.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.manageConnection) return;
    if (state == AppLifecycleState.resumed) {
      if (_page.client?.enabled.value == true) {
        unawaited(_page.client!.start(reload: true));
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _page.client?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _page.contextChanges?.cancel();
    _page.subscription?.cancel();
    if (widget.manageConnection) _page.client?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      GetBuilder<_BusinessRealtimeHostController>(
        init: _page,
        global: false,
        dispose: (state) => state.controller?.onDelete(),
        builder: (_) => widget.builder(context),
      );
}
