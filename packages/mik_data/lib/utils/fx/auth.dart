import 'business_context.dart';

import 'package:http/http.dart' as http;

import '../../source/remote/models/auth_session.dart';
import '../../source/remote/api.dart';
import '../../source/remote/auth_error.dart';
import '../../source/remote/auth_store.dart';

class AuthFX {
  static final _apps = <String, AuthFX>{};
  static AuthFX forApp(String appId) =>
      _apps.putIfAbsent(appId, () => AuthFX(appId: appId));

  final String appId;
  final AuthSessionStore store;
  final http.Client? client;
  AuthSession? current;
  Future<String?>? _refreshing;
  int? _refreshGeneration;
  Future<void> _writes = Future.value();
  int _generation = 0;

  AuthFX({required this.appId, AuthSessionStore? store, this.client})
    : store =
          store ??
          SecureAuthSessionStore(key: '$appId.auth.v1.${API.origin.origin}');

  Future<void> _persist(Future<void> Function() operation) {
    final next = _writes.then((_) => operation(), onError: (_) => operation());
    _writes = next;
    return next;
  }

  Future<bool> restore() async {
    final generation = _generation;
    final saved = await store.read();
    if (generation != _generation) return false;
    if (saved == null) {
      current = null;
      return false;
    }
    if (!saved.refreshExpiresAt.isAfter(DateTime.now().toUtc())) {
      await clear();
      return false;
    }
    current = saved;
    try {
      return await accessToken() != null;
    } on AuthError catch (error) {
      // A revoked session is a normal return to login; connectivity errors remain visible.
      if (error.requiresLogin) return false;
      rethrow;
    }
  }

  Future<AuthSession?> signIn(
    String phone,
    String otp, {
    bool registration = false,
  }) async {
    final generation = ++_generation;
    final session = await API.auth(
      {'phone': phone, 'otp': otp},
      registration: registration,
      appId: appId,
      client: client,
    );
    if (generation != _generation) return null;
    await _persist(() => store.write(session));
    if (generation != _generation) return null;
    current = session;
    return session;
  }

  Future<String?> accessToken() async {
    final session = current;
    if (session == null) return null;
    final now = DateTime.now().toUtc();
    if (!session.refreshExpiresAt.isAfter(now)) {
      await clear();
      return null;
    }
    if (session.accessExpiresAt.isAfter(now.add(const Duration(seconds: 30)))) {
      return session.accessToken;
    }
    if (_refreshing != null && _refreshGeneration == _generation) {
      return _refreshing;
    }
    final generation = _generation;
    _refreshGeneration = generation;
    return _refreshing = _refresh().whenComplete(() {
      // An older response must not release the newer session's refresh lock.
      if (_refreshGeneration == generation) _refreshing = null;
    });
  }

  Future<String?> _refresh() async {
    final session = current;
    final generation = _generation;
    if (session == null) return null;
    try {
      final next = await API.refreshAuth(session, appId: appId, client: client);
      if (generation != _generation) return null;
      await _persist(() => store.write(next));
      if (generation != _generation) return null;
      current = next;
      return next.accessToken;
    } on AuthError catch (error) {
      if (error.requiresLogin && generation == _generation) {
        await clear();
      }
      rethrow;
    }
  }

  Future<void> clear() async {
    BusinessContext.clear(appId);
    _generation++;
    current = null;
    await _persist(store.clear);
  }

  Future<Object?> request(
    String method,
    String path, {
    Object? data,
    Map<String, String>? query,
    String? branchId,
    String? idempotencyKey,
  }) async {
    final generation = _generation;
    final token = await accessToken();
    if (token == null || generation != _generation) {
      throw const AuthError(401, 'SESSION_INVALID');
    }
    try {
      return await API.request(
        method,
        path,
        data: data,
        query: query,
        appId: appId,
        accessToken: token,
        branchId: branchId,
        idempotencyKey: idempotencyKey,
        client: client,
      );
    } on AuthError catch (error) {
      if (error.requiresLogin && generation == _generation) {
        await clear();
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    final generation = _generation;
    try {
      final token = await accessToken();
      if (token != null && generation == _generation) {
        await API.logoutAuth(token, appId: appId, client: client);
      }
    } finally {
      if (generation == _generation) await clear();
    }
  }
}
