import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';
import 'package:sales_sphere_erp/features/auth/domain/repositories/auth_repository.dart';

/// Re-fetches the authenticated user from the backend. Used after
/// biometric unlock and on foregrounding to confirm the session is
/// still valid.
class RefreshSessionUseCase {
  RefreshSessionUseCase(this._repo);

  final AuthRepository _repo;

  Future<AuthUser> call() => _repo.me();
}

final refreshSessionUseCaseProvider = Provider<RefreshSessionUseCase>((ref) {
  return RefreshSessionUseCase(ref.watch(authRepositoryProvider));
});
