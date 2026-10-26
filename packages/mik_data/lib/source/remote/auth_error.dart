class AuthError implements Exception {
  final int statusCode;
  final String code;
  final bool retryable;
  final String? requestId;
  final String? serverMessage;

  const AuthError(
    this.statusCode,
    this.code, {
    this.retryable = false,
    this.requestId,
    this.serverMessage,
  });

  bool get requiresLogin => const {
    'ACCESS_TOKEN_INVALID',
    'SESSION_INVALID',
    'REFRESH_TOKEN_INVALID',
  }.contains(code);

  @override
  String toString() => 'AuthError($statusCode, $code)';
}
