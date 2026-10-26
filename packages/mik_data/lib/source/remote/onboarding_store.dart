import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/onboarding_attempt.dart';

abstract interface class OnboardingStore {
  Future<OnboardingAttempt?> read(String key);
  Future<void> write(String key, OnboardingAttempt attempt);
  Future<void> clear(String key);
}

class SecureOnboardingStore implements OnboardingStore {
  final FlutterSecureStorage storage;
  const SecureOnboardingStore({this.storage = const FlutterSecureStorage()});

  @override
  Future<OnboardingAttempt?> read(String key) async {
    final value = await storage.read(key: key);
    // A damaged pending intent must not silently become a new registration.
    return value == null ? null : OnboardingAttempt.fromJson(jsonDecode(value));
  }

  @override
  Future<void> write(String key, OnboardingAttempt attempt) =>
      storage.write(key: key, value: jsonEncode(attempt.toJson()));

  @override
  Future<void> clear(String key) => storage.delete(key: key);
}
