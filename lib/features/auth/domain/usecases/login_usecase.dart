import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';
import 'package:sales_sphere_erp/features/auth/domain/repositories/auth_repository.dart';

/// Authenticates the user against the backend and persists the session.
/// The auth boundary — even though it's a thin wrap today, this is where
/// MFA / device binding / lockout policy will land.
class LoginUseCase {
  LoginUseCase(this._repo);

  final AuthRepository _repo;

  Future<AuthUser> call({
    required String email,
    required String password,
  }) =>
      _repo.login(email: email, password: password);
}

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});
