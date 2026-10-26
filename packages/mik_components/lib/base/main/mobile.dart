import 'main.dart';

/// Compatibility frame for callers explicitly requesting a mobile page.
class MainMobile extends Main {
  const MainMobile({
    super.key,
    required super.initState,
    required super.child,
    super.header,
    super.footer,
    super.floatingActionButton,
    super.forceNet,
    super.forceSocket,
    super.loadingDuration,
  });
}
