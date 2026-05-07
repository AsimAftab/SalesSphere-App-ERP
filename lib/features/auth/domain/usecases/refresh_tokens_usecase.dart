import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/interceptors/auth_interceptor.dart';
import 'package:sales_sphere_erp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sales_sphere_erp/features/auth/domain/repositories/auth_repository.dart';

/// Exchanges a refresh token for a new access/refresh pair. Invoked by
/// the dio [AuthInterceptor] when a request returns 401 — see
/// `tokenRefreshHandlerProvider` in `core/api/dio_client.dart`.
class RefreshTokensUseCase {
  RefreshTokensUseCase(this._repo);

  final AuthRepository _repo;

  Future<TokenPair?> call(String refreshToken) =>
      _repo.refreshTokens(refreshToken);
}

final refreshTokensUseCaseProvider = Provider<RefreshTokensUseCase>((ref) {
  return RefreshTokensUseCase(ref.watch(authRepositoryProvider));
});
