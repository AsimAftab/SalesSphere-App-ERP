import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tri-state biometric-unlock preference.
enum BiometricPrefState {
  /// User has never been asked. Drives the post-login setup prompt.
  unset,

  /// User opted in. Cold-start flow will trigger the OS biometric prompt.
  enabled,

  /// User opted out. Cold-start flow skips biometric and goes through
  /// the normal session-validation + /me path.
  declined,
}

/// Persists the user's biometric-unlock preference in encrypted shared
/// preferences (same backend as token storage). Survives logout — that's
/// intentional: opt-out is a deliberate user choice. Toggle from
/// More → Settings to change.
class BiometricPreference {
  BiometricPreference(this._storage);

  static const _key = 'ss_biometric_unlock_enabled';

  final FlutterSecureStorage _storage;

  Future<BiometricPrefState> read() async {
    final raw = await _storage.read(key: _key);
    return switch (raw) {
      'true' => BiometricPrefState.enabled,
      'false' => BiometricPrefState.declined,
      _ => BiometricPrefState.unset,
    };
  }

  Future<bool> isEnabled() async =>
      (await read()) == BiometricPrefState.enabled;

  Future<void> setEnabled({required bool value}) =>
      _storage.write(key: _key, value: value.toString());

  Future<void> clear() => _storage.delete(key: _key);
}

final biometricPreferenceProvider = Provider<BiometricPreference>((_) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return BiometricPreference(storage);
});
