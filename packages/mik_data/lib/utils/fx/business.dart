import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/models/business_page.dart';
import '../../source/remote/models/business_summary.dart';
import '../../source/remote/models/business_session.dart';
import '../../source/remote/models/catalog_category.dart';
import '../../source/remote/models/onboarding_attempt.dart';
import '../../source/remote/models/onboarding_data.dart';
import '../../source/remote/models/onboarding_result.dart';
import '../../source/remote/models/product_catalog.dart';
import '../../source/remote/onboarding_store.dart';
import 'auth.dart';
import 'business_context.dart';

class BusinessFX {
  final AuthFX session;
  final OnboardingStore store;
  OnboardingAttempt? attempt;
  OnboardingResult? current;
  OnboardingData? _submitted;
  Future<OnboardingResult>? _sending;
  BusinessFX({
    required this.session,
    this.store = const SecureOnboardingStore(),
  });

  String get _key {
    final identity = session.current?.identityId;
    if (session.appId != 'mik' || identity == null) {
      throw const AuthError(401, 'SESSION_INVALID');
    }
    return 'mik.onboarding.v1.${API.origin.origin}.$identity';
  }

  Future<OnboardingAttempt?> restoreAttempt() async =>
      attempt = await store.read(_key);

  BusinessSession dashboardSession(BusinessSummary item) {
    final selected = BusinessSession(
      identityId: session.current!.identityId,
      business: item,
    );
    BusinessContext.activate(session, selected);
    return selected;
  }

  Future<List<BusinessSummary>> businesses() async {
    final sessionId = session.current?.sessionId;
    final identityId = session.current?.identityId;
    final items = <BusinessSummary>[];
    final cursors = <int>{};
    int? after;
    do {
      final page = BusinessPage.fromJson(
        await session.request(
          'GET',
          '/v1/businesses',
          query: {'limit': '100', if (after != null) 'after': '$after'},
        ),
      );
      if (session.current?.sessionId != sessionId ||
          session.current?.identityId != identityId) {
        throw const AuthError(401, 'SESSION_INVALID');
      }
      items.addAll(page.items);
      after = page.nextCursor;
      if (after != null && !cursors.add(after)) {
        throw const FormatException('Repeated business cursor');
      }
    } while (after != null);
    return List.unmodifiable(items);
  }

  Future<List<CatalogCategory>> categories({String? parentCode}) async {
    final items = <CatalogCategory>[];
    final cursors = <String>{};
    String? after;
    do {
      final page = ProductCatalog.fromJson(
        await API.request(
          'GET',
          '/v1/catalog/products',
          appId: 'mik',
          client: session.client,
          query: {'limit': '100', 'parentCode': ?parentCode, 'after': ?after},
        ),
      );
      items.addAll(page.items);
      after = page.nextCursor;
      if (after != null && !cursors.add(after)) {
        throw const FormatException('Repeated catalog cursor');
      }
    } while (after != null);
    if (items.any((item) => item.parent != parentCode)) {
      throw const FormatException('Unexpected catalog parent');
    }
    return List.unmodifiable(items);
  }

  Future<OnboardingResult> onboard(OnboardingData data) {
    if (_sending != null) {
      if (jsonEncode(_submitted!.toJson()) != jsonEncode(data.toJson())) {
        return Future.error(const AuthError(409, 'ONBOARDING_PENDING'));
      }
      return _sending!;
    }
    _submitted = data;
    return _sending = _onboard(data).whenComplete(() {
      _sending = null;
      _submitted = null;
    });
  }

  Future<OnboardingResult> _onboard(OnboardingData data) async {
    final key = _key;
    final identity = session.current!.identityId;
    final previous = await restoreAttempt();
    if (previous != null &&
        jsonEncode(previous.data.toJson()) != jsonEncode(data.toJson())) {
      throw const AuthError(409, 'ONBOARDING_PENDING');
    }
    attempt =
        previous ??
        OnboardingAttempt(idempotencyKey: const Uuid().v4(), data: data);
    await store.write(key, attempt!);
    try {
      final result = OnboardingResult.fromJson(
        await session.request(
          'POST',
          '/v1/businesses/onboarding',
          data: attempt!.data.toJson(),
          idempotencyKey: attempt!.idempotencyKey,
        ),
      );
      if (result.profile.identityId != identity ||
          session.current?.identityId != identity) {
        throw const FormatException('Unexpected onboarding identity');
      }
      await store.clear(key);
      attempt = null;
      current = result;
      BusinessContext.activate(session, BusinessSession.fromOnboarding(result));
      return result;
    } on AuthError catch (error) {
      // These errors occur before creating the business; editing is safe.
      if (['VALIDATION_FAILED', 'REFERRAL_INVALID'].contains(error.code)) {
        await store.clear(key);
        attempt = null;
      }
      rethrow;
    }
  }

  static String message(Object error) {
    if (error is AuthError) {
      switch (error.code) {
        case 'FORBIDDEN':
        case 'SCOPE_UNAVAILABLE':
          return 'به این کسب‌وکار یا شعبه دسترسی ندارید.';
        case 'SELECTION_CHANGED':
          return 'انتخاب کسب‌وکار یا شعبه تغییر کرده است. دوباره انتخاب کنید.';
        case 'REFERRAL_INVALID':
          return 'کد معرف معتبر نیست.';
        case 'VALIDATION_FAILED':
          return 'اطلاعات واردشده را بررسی کنید.';
        case 'ONBOARDING_PENDING':
        case 'IDEMPOTENCY_CONFLICT':
          return 'ثبت قبلی هنوز تعیین تکلیف نشده؛ همان اطلاعات را دوباره ارسال کنید.';
      }
    }
    if (error is FormatException) {
      return 'پاسخ سرور کامل نیست. دوباره تلاش کنید.';
    }
    return API.loginError(error);
  }
}
