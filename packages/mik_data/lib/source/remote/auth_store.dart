import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/auth_session.dart';

abstract interface class AuthSessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

class SecureAuthSessionStore implements AuthSessionStore {
  final String key;
  final FlutterSecureStorage storage;
  const SecureAuthSessionStore({
    required this.key,
    this.storage = const FlutterSecureStorage(),
  });

  @override
  Future<AuthSession?> read() async {
    final stored = await storage.read(key: key);
    if (stored == null) return null;
    try {
      return AuthSession.fromStorage(
        Map<String, dynamic>.from(jsonDecode(stored)),
      );
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) =>
      storage.write(key: key, value: jsonEncode(session.toStorage()));

  @override
  Future<void> clear() => storage.delete(key: key);
}
