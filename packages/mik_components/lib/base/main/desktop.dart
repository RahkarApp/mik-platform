import 'main.dart';

/// Hosts can provide their desktop shell through ComponentHost.pageShell.
class MainDesktop extends Main {
  const MainDesktop({
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
