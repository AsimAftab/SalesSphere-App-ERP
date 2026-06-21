import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sales_sphere_erp/features/auth/domain/repositories/auth_repository.dart';

/// Changes the authenticated user's password. An auth-boundary write —
/// even though it's a thin wrap today, this is where future policy
/// (re-auth prompts, breached-password checks, lockout) will land.
/// Returns the backend's confirmation message.
class ChangePasswordUseCase {
  ChangePasswordUseCase(this._repo);

  final AuthRepository _repo;

  Future<String> call({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) =>
      _repo.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
}

final changePasswordUseCaseProvider = Provider<ChangePasswordUseCase>((ref) {
  return ChangePasswordUseCase(ref.watch(authRepositoryProvider));
});
