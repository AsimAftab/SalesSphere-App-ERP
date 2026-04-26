import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps [FlutterSecureStorage] with the SalesSphere token contract.
/// Tokens are stored in EncryptedSharedPreferences on Android.
class TokenStorage {
  TokenStorage(this._storage);

  static const _accessTokenKey = 'ss_access_token';
  static const _refreshTokenKey = 'ss_refresh_token';
  static const _expiryKey = 'ss_token_expires_at';

  final FlutterSecureStorage _storage;

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<DateTime?> readExpiry() async {
    final raw = await _storage.read(key: _expiryKey);
    if (raw == null) return null;
    final ts = int.tryParse(raw);
    return ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    DateTime? expiresAt,
  }) async {
    await Future.wait(<Future<void>>[
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      if (expiresAt != null)
        _storage.write(
          key: _expiryKey,
          value: expiresAt.millisecondsSinceEpoch.toString(),
        )
      else
        _storage.delete(key: _expiryKey),
    ]);
  }

  Future<void> clear() async {
    await Future.wait(<Future<void>>[
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiryKey),
    ]);
  }

  Future<bool> hasSession() async {
    final access = await readAccessToken();
    return access != null && access.isNotEmpty;
  }
}

final tokenStorageProvider = Provider<TokenStorage>((_) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return TokenStorage(storage);
});
