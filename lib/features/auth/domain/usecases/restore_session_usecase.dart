import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/auth/biometric_service.dart';
import 'package:sales_sphere_erp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';
import 'package:sales_sphere_erp/features/auth/domain/repositories/auth_repository.dart';

/// Outcome of cold-start session restoration. The controller pattern-matches
/// this to drive [AuthState] without having to repeat the decision tree.
sealed class RestoreSessionResult {
  const RestoreSessionResult();
}

/// No (or expired) session — the user must log in.
class RestoreSessionUnauthenticated extends RestoreSessionResult {
  const RestoreSessionUnauthenticated();
}

/// We have a session and a cached user, plus biometric hardware. The UI
/// should prompt for biometric unlock before continuing.
class RestoreSessionBiometric extends RestoreSessionResult {
  const RestoreSessionBiometric(this.cachedUser);
  final AuthUser cachedUser;
}

/// Session is live and verified — go straight to the home shell.
class RestoreSessionAuthenticated extends RestoreSessionResult {
  const RestoreSessionAuthenticated(this.user);
  final AuthUser user;
}

/// Composes [AuthRepository.hasSession], [AuthRepository.cachedUser],
/// [AuthRepository.me], and biometric availability into a single decision
/// for the controller's `_resolveStartup` path.
class RestoreSessionUseCase {
  RestoreSessionUseCase({
    required AuthRepository repo,
    required BiometricService biometric,
  })  : _repo = repo,
        _biometric = biometric;

  final AuthRepository _repo;
  final BiometricService _biometric;

  Future<RestoreSessionResult> call() async {
    if (!await _repo.hasSession()) {
      return const RestoreSessionUnauthenticated();
    }
    final cached = await _repo.cachedUser();
    if (cached != null && await _biometric.isAvailable) {
      return RestoreSessionBiometric(cached);
    }
    try {
      final user = await _repo.me();
      return RestoreSessionAuthenticated(user);
    } catch (_) {
      return const RestoreSessionUnauthenticated();
    }
  }
}

final restoreSessionUseCaseProvider = Provider<RestoreSessionUseCase>((ref) {
  return RestoreSessionUseCase(
    repo: ref.watch(authRepositoryProvider),
    biometric: ref.watch(biometricServiceProvider),
  );
});
