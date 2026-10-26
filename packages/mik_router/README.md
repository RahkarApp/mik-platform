# MiK routing

`mik_router` contains route names, navigation, transitions, argument validation,
and an optional guard. It depends only on Flutter. It does not import either
application, `mik_data`, or `mik_pages`.

## Shared and application pages

- `mik_pages/lib/routing/shared_routes.dart`: registers the available shared pages.
- Each application's own `core/router/`: registers its startup, dashboard, lock,
  settings, integrations, and other private pages.
- App registrations override shared registrations for the same path.
- Authentication and database readiness checks belong to the host's `guard`.
  The core router does not assume a token, Hive box, or app-specific boot flow.

The shared pages expect `mik_data` models and boxes. MiK now uses this router in
`mik-app/lib/core/router/routing.dart` and initializes host bindings in
`mik-app/lib/core/package_bindings.dart`. Its legacy data/model import paths are
compatibility exports of the shared packages. MiKyar continues to use its own
router until its corresponding migration is completed.

Customer details now uses the canonical shared model and is registered in
`SharedRoutes.pages()`.

## Configure an application

Construct one router at startup, after deciding which pages this application uses:

```dart
import 'package:mik_router/mik_router.dart';
import 'package:mik_pages/routing/shared_routes.dart';

final router = MikRouter(
  sharedRoutes: SharedRoutes.pages(includeMikLogin: true),
  appRoutes: {
    RoutesName.MAIN: (settings) => AppStartupPage(),
    RoutesName.DASHBOARD: (settings) => MikDashboardPage(),
    RoutesName.DRAWER_SETTINGS: (settings) => MikSettingsPage(),
  },
);

// MaterialApp / GetMaterialApp:
// onGenerateRoute: router.generateRoute,
```

`AppStartupPage`, `MikDashboardPage`, and `MikSettingsPage` above stand for widgets
owned by the host application.

For mikyar, keep its own login and dashboard. The shared login currently uses the
MiK authentication endpoints and registration flow; it is opt-in:

```dart
final router = MikRouter(
  sharedRoutes: SharedRoutes.pages(),
  appRoutes: {
    RoutesName.MAIN: (_) => MikyarStartupPage(),
    RoutesName.LOGIN: (_) => MikyarLoginPage(),
    RoutesName.GETDATA: (_) => MikyarDataPage(),
    RoutesName.DASHBOARD: (_) => MikyarDashboardPage(),
  },
);
```

Provide `guard` to redirect requests until boot/authentication is complete and
`pageWrapper` if the host needs providers around each page. Both are optional.
A guard returns the requested `RouteSettings` when navigation is allowed, or
settings for a host-owned startup/login page when redirection is required.

`RouteGenerator.configure(...)` accepts the same route maps for hosts that prefer
the existing static `RouteGenerator.generateRoute` entry point. Configure it once
before `runApp`.

Query strings do not affect route matching. The original route name and arguments
remain available through `RouteSettings`. Missing routes show a not-found page;
invalid required arguments show an error page instead of opening a dashboard.
