/// Pair of (access, refresh) tokens returned by the auth backend.
///
/// Lives in the auth domain so the repository contract can stay free
/// of an `import` from the dio interceptor / API layer. Both the
/// interceptor and the repository implementation refer to this
/// domain type when they exchange refreshed tokens.
class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;
}
