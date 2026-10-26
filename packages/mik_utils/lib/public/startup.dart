import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:universal_io/io.dart';

class StartupFX {
  static Future<void> prepare({Future<void> Function()? initialize}) async {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: AppColors.primary.withValues(alpha: 0.3),
        statusBarColor: AppColors.primary,
      ),
    );
    await initialize?.call();
  }

  static Future<({Directory root, Directory products, Directory users})?>
  directories(Future<Directory> Function() readDirectory) async {
    if (kIsWeb) return null;
    final root = await readDirectory();
    final products = Directory('${root.path}/img/product');
    final users = Directory('${root.path}/img/user');
    await products.create(recursive: true);
    await users.create(recursive: true);
    return (root: root, products: products, users: users);
  }

  static void updateLayout(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    appContext = context;
    widthScreen.value = size.width;
    heightScreen.value = size.height;
    topPadding = padding.top;
    bottomPadding = padding.bottom;
    statusBarHeight.value = padding.top;
    isMobile.value = size.width < 700;
    isTablet.value = size.width >= 700 && size.width < 1000;
    isDesktop.value = size.width >= 1000;
  }

  static String? initialRoute(String? path) {
    if (path == null || path.isEmpty) return null;
    final uri = Uri.tryParse(path);
    if (uri == null ||
        {'', '/', '/splash', '/SplashScreen'}.contains(uri.path)) {
      return null;
    }
    return path;
  }

  static String? browserRoute(Uri uri) => initialRoute(
    uri.fragment.startsWith('/')
        ? uri.fragment
        : '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}',
  );

  static String? launchRoute() => kIsWeb
      ? browserRoute(Uri.base)
      : initialRoute(
          WidgetsBinding.instance.platformDispatcher.defaultRouteName,
        );
}
