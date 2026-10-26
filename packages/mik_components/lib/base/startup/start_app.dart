import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_utils/public/startup.dart';
import 'package:mik_variables/variable.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:toastification/toastification.dart';

class StartApp extends StatefulWidget {
  final String title;
  final Widget home;
  final RouteFactory onGenerateRoute;
  final bool Function() useSystemTheme;
  final Future<void> Function()? onStart;
  final TransitionBuilder? appBuilder;

  const StartApp({
    super.key,
    required this.title,
    required this.home,
    required this.onGenerateRoute,
    required this.useSystemTheme,
    this.onStart,
    this.appBuilder,
  });

  @override
  State<StartApp> createState() => _StartAppState();
}

class _StartAppState extends State<StartApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _systemTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    try {
      await widget.onStart?.call();
    } catch (error) {
      debugPrint('Startup connection unavailable: ${error.runtimeType}');
    }
  }

  void _systemTheme() {
    if (widget.useSystemTheme()) {
      darkMode.value =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
  }

  @override
  void didChangePlatformBrightness() => _systemTheme();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'ravi',
      fontFamilyFallback: const ['ravi'],
      primaryColor: dark ? AppColors.grey : AppColors.primary,
      scaffoldBackgroundColor: dark
          ? AppColors.backgroundDarkMode
          : AppColors.background,
      colorScheme: dark
          ? ColorScheme.dark(
              surface: AppColors.backgroundDarkMode,
              error: AppColors.error,
              primary: AppColors.grey,
              secondary: AppColors.secondary,
            )
          : ColorScheme.light(
              surface: AppColors.background,
              error: AppColors.error,
              primary: AppColors.primary,
              secondary: AppColors.secondary,
            ),
      brightness: brightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      config: ToastificationConfig(
        maxTitleLines: 2,
        maxDescriptionLines: 6,
        marginBuilder: (context, alignment) =>
            const EdgeInsets.fromLTRB(0, 16, 0, 110),
      ),
      child: Obx(
        () => GetMaterialApp(
          title: widget.title,
          home: widget.home,
          initialRoute: '/',
          locale: const Locale('fa', 'IR'),
          supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
          localizationsDelegates: const [
            PersianMaterialLocalizations.delegate,
            PersianCupertinoLocalizations.delegate,
          ],
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: darkMode.value ? ThemeMode.dark : ThemeMode.light,
          defaultTransition: Transition.rightToLeftWithFade,
          fallbackLocale: const Locale('fa'),
          smartManagement: SmartManagement.full,
          debugShowCheckedModeBanner: false,
          onGenerateRoute: widget.onGenerateRoute,
          builder: (context, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && context.mounted) StartupFX.updateLayout(context);
            });
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1)),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child:
                    widget.appBuilder?.call(context, child) ??
                    child ??
                    const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    );
  }
}
