import 'package:flutter/material.dart';

export 'route_names.dart';

/// The host application supplies widgets; the router has no page/data imports.
typedef MikPageBuilder = Widget Function(RouteSettings settings);
typedef MikRouteGuard = RouteSettings Function(RouteSettings settings);
typedef MikPageWrapper = Widget Function(BuildContext context, Widget child);

class MikRouter {
  final Map<String, MikPageBuilder> sharedRoutes;
  final Map<String, MikPageBuilder> appRoutes;
  final MikRouteGuard? guard;
  final MikPageWrapper? pageWrapper;
  final MikPageBuilder? unknownPage;
  final Duration transitionDuration;

  MikRouter({
    Map<String, MikPageBuilder> sharedRoutes = const {},
    Map<String, MikPageBuilder> appRoutes = const {},
    this.guard,
    this.pageWrapper,
    this.unknownPage,
    this.transitionDuration = const Duration(milliseconds: 500),
  }) : sharedRoutes = Map.unmodifiable(sharedRoutes),
       appRoutes = Map.unmodifiable(appRoutes);

  static String pathOf(String? name) {
    if (name == null || name.isEmpty) return '/';
    final uri = Uri.tryParse(name);
    if (uri == null) return name.split('?').first;
    return uri.path.isEmpty ? '/' : uri.path;
  }

  bool canHandle(String? name) {
    final path = pathOf(name);
    return appRoutes.containsKey(path) || sharedRoutes.containsKey(path);
  }

  Route<dynamic> generateRoute(RouteSettings requested) {
    final settings = guard?.call(requested) ?? requested;
    final path = pathOf(settings.name);
    // The host can override a shared route, e.g. the two apps' login screens.
    final builder = appRoutes[path] ?? sharedRoutes[path] ?? unknownPage;
    Widget page;
    try {
      page = builder?.call(settings) ?? const _RouteErrorPage();
    } on ArgumentError {
      page = const _RouteErrorPage(invalidArguments: true);
    }
    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) =>
          pageWrapper?.call(context, page) ?? page,
      transitionDuration: transitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

/// Compatibility entry point for existing `onGenerateRoute` call sites.
class RouteGenerator {
  static MikRouter _router = MikRouter();

  static void configure({
    Map<String, MikPageBuilder> sharedRoutes = const {},
    Map<String, MikPageBuilder> appRoutes = const {},
    MikRouteGuard? guard,
    MikPageWrapper? pageWrapper,
    MikPageBuilder? unknownPage,
  }) {
    _router = MikRouter(
      sharedRoutes: sharedRoutes,
      appRoutes: appRoutes,
      guard: guard,
      pageWrapper: pageWrapper,
      unknownPage: unknownPage,
    );
  }

  static Route<dynamic> generateRoute(RouteSettings settings) =>
      _router.generateRoute(settings);
}

/// Safely reads the existing map-based route arguments.
class RouteArguments {
  final Map<dynamic, dynamic> _values;

  RouteArguments(RouteSettings settings)
    : _values = settings.arguments is Map
          ? settings.arguments as Map
          : const {};

  T? optional<T>(String name) {
    final value = _values[name];
    if (value == null) return null;
    if (value is! T) {
      throw ArgumentError.value(value, name, 'Invalid route argument');
    }
    return value;
  }

  T required<T>(String name) {
    final value = optional<T>(name);
    if (value == null) throw ArgumentError.notNull(name);
    return value;
  }
}

class _RouteErrorPage extends StatelessWidget {
  final bool invalidArguments;
  const _RouteErrorPage({this.invalidArguments = false});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('صفحه در دسترس نیست')),
    body: Center(
      child: Text(
        invalidArguments
            ? 'اطلاعات لازم برای نمایش این صفحه موجود نیست.'
            : 'صفحهٔ موردنظر پیدا نشد.',
      ),
    ),
  );
}
