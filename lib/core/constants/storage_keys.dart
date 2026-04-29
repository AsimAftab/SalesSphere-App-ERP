import 'package:flutter/material.dart';

/// Persistent storage key constants
class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String user = 'user';
  static const String locale = 'locale';
  static const String themeMode = 'theme_mode';
  static const String biometricEnabled = 'biometric_enabled';

  static const ThemeMode defaultThemeMode = ThemeMode.system;
}
