import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_variables/variable.dart' as state;
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_data/source/remote/models/business_branch.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/business_summary.dart';
import 'package:mik_data/source/remote/models/business_session.dart';
import 'package:mik_router/route_names.dart';
import 'package:mik_data/utils/fx/auth.dart';
import 'package:mik_data/utils/fx/business.dart';

import '../components/business_selection.dart';
import 'register.dart';

class MikAccountScreen extends StatefulWidget {
  final AuthFX session;
  final BusinessFX? business;
  final Future<void> Function(BusinessSession)? onSelected;
  final Future<void> Function() onLogout;
  const MikAccountScreen({
    super.key,
    required this.session,
    required this.onLogout,
    this.business,
    this.onSelected,
  });
  @override
  State<MikAccountScreen> createState() => _MikAccountScreenState();
}

class _MikAccountScreenController extends GetxController {
  _MikAccountScreenController(this.widget);
  MikAccountScreen widget;
  late final _business = widget.business ?? BusinessFX(session: widget.session);
  final _items = <BusinessSummary>[];
  bool _opening = false;
  bool _busy = false;
  BusinessContext? _context;
  List<BusinessBranch> _branches = const [];
  String? _selectionError;
}

class _MikAccountScreenState extends State<MikAccountScreen> {
  late final _page = _MikAccountScreenController(widget);

  Future<Object> _load() async {
    try {
      final pending = widget.session.appId == 'mik'
          ? await _page._business.restoreAttempt()
          : null;
      if (pending == null) {
        final items = await _page._business.businesses();
        _page._items
          ..clear()
          ..addAll(items);
        if (_page._items.length == 1) await _select(_page._items.single);
      }
      return '';
    } catch (error) {
      if (error is AuthError && error.requiresLogin && mounted) {
        await widget.onLogout();
        return '';
      }
      throw BusinessFX.message(error);
    }
  }

  Future<void> _select(BusinessSummary item) async {
    if (!mounted || _page._busy || _page._opening) return;
    {
      _page._busy = true;
      _page._selectionError = null;
      _page._context = null;
      _page.update();
    }
    try {
      state.PermissionAccess.clear();
      state.permissions.clear();
      state.branchs.clear();
      state.warehouses.clear();
      _page._business.dashboardSession(item);
      final context = BusinessContext.forApp(widget.session.appId)!;
      await context.authorize();
      final branches = await context.branches();
      if (!mounted) return;
      {
        _page._context = context;
        _page._branches = branches;
        _page.update();
      }
      if (branches.length == 1) await _openBranch(branches.single);
    } catch (error) {
      if (error is AuthError && error.requiresLogin && mounted) {
        await widget.onLogout();
      } else if (mounted) {
        {
          _page._selectionError = BusinessFX.message(error);
          _page.update();
        }
      }
    } finally {
      if (mounted) {
        _page._busy = false;
        _page.update();
      }
    }
  }

  Future<void> _openBranch(BusinessBranch branch) async {
    final context = _page._context;
    if (context == null || _page._opening) return;
    try {
      await context.selectBranch(branch);
      if (!mounted) return;
      _page._opening = true;
      if (widget.onSelected != null) {
        await widget.onSelected!(context.session);
      } else {
        Get.offAllNamed(RoutesName.DASHBOARD, arguments: context.session);
      }
    } catch (error) {
      _page._opening = false;
      if (error is AuthError && error.requiresLogin && mounted) {
        await widget.onLogout();
      } else if (mounted) {
        Alert.error(BusinessFX.message(error), context: this.context);
      }
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_MikAccountScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: _load,
      child: (_) {
        if (_page._opening) return const SizedBox.shrink();
        if (_page._busy)
          return const Center(child: CircularProgressIndicator());
        if (_page._selectionError != null) {
          return BusinessSelection(
            items: _page._items,
            onSelected: _select,
            onLogout: widget.onLogout,
            error: _page._selectionError,
          );
        }
        if (_page._context != null) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'انتخاب شعبه',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              if (_page._branches.isEmpty)
                const Text('شعبهٔ فعال و قابل دسترسی وجود ندارد.'),
              for (final branch in _page._branches)
                ListTile(
                  title: Text(branch.name),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () async {
                    if (_page._busy) return;
                    {
                      _page._busy = true;
                      _page.update();
                    }
                    try {
                      await _openBranch(branch);
                    } finally {
                      if (mounted) {
                        _page._busy = false;
                        _page.update();
                      }
                    }
                  },
                ),
              BTN(
                name: 'انتخاب کسب‌وکار',
                navigate: true,
                onTap: () {
                  BusinessContext.clear(widget.session.appId);
                  {
                    _page._context = null;
                    _page._branches = const [];
                    _page.update();
                  }
                },
              ),
              BTN(name: 'خروج از حساب', navigate: true, onTap: widget.onLogout),
            ],
          );
        }
        if (_page._items.isEmpty && widget.session.appId != 'mik') {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('عضویت فعال در هیچ کسب‌وکاری ندارید.'),
              BTN(name: 'خروج از حساب', onTap: widget.onLogout),
            ],
          );
        }
        if (_page._items.isEmpty) {
          return RegisterScreen(
            business: _page._business,
            onLogout: widget.onLogout,
            onCompleted: (result) async {
              if (mounted) {
                final selected = BusinessSession.fromOnboarding(result);
                Get.offAllNamed(RoutesName.WELCOME, arguments: selected);
              }
            },
          );
        }
        return BusinessSelection(
          items: _page._items,
          onSelected: _select,
          onLogout: widget.onLogout,
        );
      },
    ),
  );

  @override
  void didUpdateWidget(covariant MikAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}
