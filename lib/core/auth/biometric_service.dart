import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:sales_sphere_erp/core/utils/app_logger.dart';
import 'package:sales_sphere_erp/core/utils/app_logger_provider.dart';

/// Wraps `local_auth` so the rest of the app deals in a tiny, testable
/// surface (and we can swap the package without touching consumers).
class BiometricService {
  BiometricService(this._auth, this._logger);

  final LocalAuthentication _auth;
  final AppLogger _logger;

  /// True if the device has biometric hardware AND the user has at least
  /// one biometric enrolled (fingerprint, face, etc.).
  Future<bool> get isAvailable async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (e, st) {
      _logger.warn('Biometric availability check failed',
          error: e, stackTrace: st);
      return false;
    }
  }

  /// Prompt the user to authenticate with whatever biometric they have
  /// enrolled. Returns `true` on success, `false` on cancel / fallback.
  Future<bool> authenticate({
    String localizedReason = 'Unlock SalesSphere',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e, st) {
      _logger.warn('Biometric auth failed', error: e, stackTrace: st);
      return false;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService(
    LocalAuthentication(),
    ref.watch(appLoggerProvider),
  );
});
