abstract interface class AuthGateway {
  String? get accessToken;

  bool get needsRefresh;

  Future<void> refreshTokens();

  Future<void> sessionLost();
}
