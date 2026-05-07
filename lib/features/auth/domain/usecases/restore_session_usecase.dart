import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/auth/biometric_preference.dart';
import 'package:sales_sphere_erp/core/auth/biometric_service.dart';
import 'package:sales_sphere_erp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';
import 'package:sales_sphere_erp/features/auth/domain/repositories/auth_repository.dart';

/// Outcome of cold-start session restoration. The controller pattern-matches
/// this to drive `AuthState` without having to repeat the decision tree.
sealed class RestoreSessionResult {
  const RestoreSessionResult();
}

/// No (or expired) session — the user must log in.
class RestoreSessionUnauthenticated extends RestoreSessionResult {
  const RestoreSessionUnauthenticated();
}

/// We have a live session, biometric hardware, opt-in preference, and a
/// cached user. The controller should fire the OS biometric prompt.
class RestoreSessionBiometric extends RestoreSessionResult {
  const RestoreSessionBiometric(this.cachedUser);
  final AuthUser cachedUser;
}

/// Session is live and verified — go straight to the home shell.
class RestoreSessionAuthenticated extends RestoreSessionResult {
  const RestoreSessionAuthenticated(this.user);
  final AuthUser user;
}

/// Composes [AuthRepository.hasSession], [AuthRepository.validateSession],
/// [AuthRepository.cachedUser], [AuthRepository.me], biometric availability,
/// and the user's [BiometricPreference] into a single decision for the
/// controller's `_resolveStartup` path.
class RestoreSessionUseCase {
  RestoreSessionUseCase({
    required AuthRepository repo,
    required BiometricService biometric,
    required BiometricPreference biometricPref,
  })  : _repo = repo,
        _biometric = biometric,
        _biometricPref = biometricPref;

  final AuthRepository _repo;
  final BiometricService _biometric;
  final BiometricPreference _biometricPref;

  Future<RestoreSessionResult> call() async {
    if (!await _repo.hasSession()) {
      return const RestoreSessionUnauthenticated();
    }

    // Ping /auth/session — the auth interceptor's refresh path runs
    // transparently on 401, so a `false` here means the access AND
    // refresh tokens are both dead. No point prompting biometric.
    if (!await _repo.validateSession()) {
      return const RestoreSessionUnauthenticated();
    }

    final cached = await _repo.cachedUser();
    final wantsBiometric = await _biometricPref.isEnabled();
    if (cached != null &&
        wantsBiometric &&
        await _biometric.isAvailable) {
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
    biometricPref: ref.watch(biometricPreferenceProvider),
  );
});
