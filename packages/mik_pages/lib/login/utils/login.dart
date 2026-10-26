import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_data/source/remote/api.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/auth.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../components/registration_confirmation.dart';
import '../screen/screen.dart';

bool reg = false;

class LoginFunc {
  static Future<bool> submitMobile(
    BuildContext context,
    String act,
    String mobile, {
    String appId = 'mik',
    bool allowRegistration = true,
    AuthFX? session,
  }) async {
    final auth = session ?? AuthFX.forApp(appId);
    if (act == 'reg' && (!allowRegistration || appId == 'mikyar')) {
      Alert.error('ثبت‌نام از طریق میکیار امکان‌پذیر نیست.', context: context);
      return false;
    }
    loading.value = true;
    try {
      await API.login(act, mobile, appId: appId, client: auth.client);
      if (!context.mounted) return false;
      reg = appId == 'mik' && act == 'reg';
      authCode.value = true;
      return true;
    } catch (error) {
      if (!context.mounted) return false;
      if (error is AuthError &&
          error.code == 'USER_NOT_FOUND' &&
          act == 'login' &&
          appId == 'mik' &&
          allowRegistration) {
        loading.value = false;
        return await showRegistration(context, mobile, session: auth);
      }
      Alert.error(API.loginError(error, appId: appId), context: context);
      return false;
    } finally {
      loading.value = false;
    }
  }

  static Future<bool> showRegistration(
    BuildContext context,
    String mobile, {
    VoidCallback? onSent,
    AuthFX? session,
  }) async {
    final result = await MyBottomSheet.view(
      context,
      child: (_) => RegistrationConfirmation(
        onConditions: () => showLoginConditions(context),
        onConfirm: () => submitMobile(context, 'reg', mobile, session: session),
      ),
      title: 'ثبت‌نام در میک',
      isDismissible: false,
    );
    if (result == true && context.mounted) {
      onSent?.call();
      return true;
    }
    return false;
  }

  static Future<bool> callToLogin(String mobile, {String appId = 'mik'}) async {
    try {
      await API.login(
        appId == 'mik' && reg ? 'reg' : 'login',
        mobile,
        appId: appId,
      );
      return true;
    } catch (error) {
      Alert.error(API.loginError(error, appId: appId));
      return false;
    }
  }

  static Future<dynamic> auth(
    String mobile,
    String code, {
    String appId = 'mik',
    AuthFX? session,
  }) async {
    loading.value = true;
    try {
      final auth = session ?? AuthFX.forApp(appId);
      final result = await auth.signIn(
        mobile,
        code,
        registration: appId == 'mik' && reg,
      );
      if (result == null) return 'false';
      await authListen?.cancel();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await SmsAutoFill().unregisterListener();
        } catch (_) {}
      }
      return true;
    } catch (error) {
      Alert.error(API.loginError(error, appId: appId));
      return 'false';
    } finally {
      loading.value = false;
    }
  }
}
