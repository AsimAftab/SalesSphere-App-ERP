import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/auth/biometric_preference.dart';
import 'package:sales_sphere_erp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sales_sphere_erp/features/auth/domain/repositories/auth_repository.dart';

/// Signs the user out — clears tokens, drops cached user rows, tells the
/// backend to revoke the session, AND resets the biometric-unlock
/// preference so the user is re-prompted on the next login. Treating
/// opt-in as session-bound consent (rather than lifetime consent)
/// matches the model most sensitive-account apps use.
class LogoutUseCase {
  LogoutUseCase({
    required AuthRepository repo,
    required BiometricPreference biometricPref,
  })  : _repo = repo,
        _biometricPref = biometricPref;

  final AuthRepository _repo;
  final BiometricPreference _biometricPref;

  Future<void> call() async {
    await _repo.logout();
    await _biometricPref.clear();
  }
}

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(
    repo: ref.watch(authRepositoryProvider),
    biometricPref: ref.watch(biometricPreferenceProvider),
  );
});
