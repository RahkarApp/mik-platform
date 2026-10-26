class AuthSession {
  final String identityId, sessionId, accessToken, refreshToken;
  final DateTime accessExpiresAt, refreshExpiresAt;

  const AuthSession({
    required this.identityId,
    required this.sessionId,
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });

  factory AuthSession.fromJson(Object? value, {DateTime? receivedAt}) {
    if (value is! Map || value['subjectType'] != 'WORKFORCE') {
      throw const FormatException('Invalid authentication response');
    }
    String field(String key) {
      final result = value[key];
      if (result is! String || result.isEmpty) {
        throw const FormatException('Incomplete authentication response');
      }
      return result;
    }

    int lifetime(String key) {
      final result = value[key];
      if (result is! int || result <= 0) {
        throw const FormatException('Invalid token lifetime');
      }
      return result;
    }

    final now = (receivedAt ?? DateTime.now()).toUtc();
    return AuthSession(
      identityId: field('identityId'),
      sessionId: field('sessionId'),
      accessToken: field('accessToken'),
      refreshToken: field('refreshToken'),
      accessExpiresAt: now.add(
        Duration(seconds: lifetime('accessTokenExpiresInSeconds')),
      ),
      refreshExpiresAt: now.add(
        Duration(seconds: lifetime('refreshTokenExpiresInSeconds')),
      ),
    );
  }

  Map<String, Object> toStorage() => {
    'identityId': identityId,
    'sessionId': sessionId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessExpiresAt': accessExpiresAt.toIso8601String(),
    'refreshExpiresAt': refreshExpiresAt.toIso8601String(),
  };

  factory AuthSession.fromStorage(Map<String, dynamic> value) {
    String field(String key) {
      final result = value[key];
      if (result is! String || result.isEmpty) {
        throw const FormatException('Invalid saved authentication');
      }
      return result;
    }

    return AuthSession(
      identityId: field('identityId'),
      sessionId: field('sessionId'),
      accessToken: field('accessToken'),
      refreshToken: field('refreshToken'),
      accessExpiresAt: DateTime.parse(field('accessExpiresAt')).toUtc(),
      refreshExpiresAt: DateTime.parse(field('refreshExpiresAt')).toUtc(),
    );
  }

  @override
  String toString() => 'AuthSession([redacted])';
}
