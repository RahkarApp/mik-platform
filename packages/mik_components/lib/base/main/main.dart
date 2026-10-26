import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/disconnectSocket.dart';
import 'package:mik_components/base/disconnected.dart';
import 'package:mik_components/base/error.dart';
import 'package:mik_components/base/vpn.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/host.dart';
import 'package:mik_variables/variable.dart';

enum LoadingState { Error, Loading, Success }

typedef RenderSuccessCallback = Widget Function(dynamic data);
typedef InitStateCallback = Future<Object> Function();

/// Shared page frame. Navigation shells and private panels belong to the host.
class Main extends StatefulWidget {
  final InitStateCallback initState;
  final RenderSuccessCallback child;
  final Widget? header, footer, floatingActionButton;
  final bool forceNet, forceSocket, confirmBack;
  final dynamic onTapConfirm;
  final int? loadingDuration;

  const Main({
    super.key,
    required this.initState,
    required this.child,
    this.header,
    this.footer,
    this.floatingActionButton,
    this.forceNet = false,
    this.forceSocket = false,
    this.confirmBack = false,
    this.onTapConfirm,
    this.loadingDuration,
  });

  @override
  State<Main> createState() => _MainState();
}

class _MainController extends GetxController {
  LoadingState _state = LoadingState.Loading;
  dynamic _data, _error;
}

class _MainState extends State<Main> {
  late final _page = _MainController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      _page._state = LoadingState.Loading;
      _page.update();
    }
    try {
      final result = await widget.initState();
      if (!mounted) return;
      {
        _page._data = result;
        _page._state = LoadingState.Success;
        _page.update();
      }
    } catch (error) {
      if (!mounted) return;
      {
        _page._error = error;
        _page._state = LoadingState.Error;
        _page.update();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_MainController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final page = PopScope(
          canPop: !widget.confirmBack,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await Confirm.con(
              context,
              type: ConfirmType.BACK,
              confirmText: 'ذخیره و بازگشت',
              cancelText: 'بازگشت بدون ذخیره',
              onTapConfirm: () async {
                if (widget.onTapConfirm != null) await widget.onTapConfirm();
                Get.back();
              },
              onTapCancel: () {
                Get.back();
                Get.back();
              },
            );
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            floatingActionButton: widget.floatingActionButton,
            floatingActionButtonLocation:
                FloatingActionButtonLocation.startDocked,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.header != null) widget.header!,
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: switch (_page._state) {
                            LoadingState.Loading => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            LoadingState.Error => ErrorPage(
                              _page._error,
                              onTap: _load,
                            ),
                            LoadingState.Success => widget.child(_page._data),
                          },
                        ),
                        // Obx(() {
                        //   if (vpn.value) return const VPNPage();
                        //   if (widget.forceNet && !internetCheck.value)
                        //     return Disconnected();
                        //   if ((widget.forceSocket || widget.forceNet) &&
                        //       socketConnected.value == 'error') {
                        //     return DisconnectSocket();
                        //   }
                        //   return const SizedBox.shrink();
                        // }),
                      ],
                    ),
                  ),
                  if (widget.footer != null) widget.footer!,
                ],
              ),
            ),
          ),
        );
        return ComponentHost.pageShell?.call(context, page) ?? page;
      },
    );
  }
}
