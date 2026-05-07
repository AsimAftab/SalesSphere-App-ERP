import 'package:sales_sphere_erp/core/api/interceptors/auth_interceptor.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';

/// Domain-side contract for authentication. Concrete implementation
/// (DTO mapping, secure-storage writes, drift persistence) lives in
/// `data/repositories/auth_repository_impl.dart`.
abstract class AuthRepository {
  Future<AuthUser> login({
    required String email,
    required String password,
  });

  /// Re-fetches the authenticated user from the backend. Used after
  /// biometric unlock and on app foregrounding to confirm the session
  /// is still valid.
  Future<AuthUser> me();

  /// Lightweight access-token validity check. Returns true when the
  /// backend reports `valid: true && mobileLoginAllowed: true`. Lets the
  /// app skip a biometric prompt when the session is already dead and
  /// the auth interceptor's refresh path can't recover it.
  Future<bool> validateSession();

  Future<TokenPair?> refreshTokens(String refreshToken);

  Future<void> logout();

  Future<AuthUser?> cachedUser();

  Future<bool> hasSession();
}
