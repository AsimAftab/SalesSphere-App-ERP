import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides a synchronously accessible instance of [SharedPreferences].
/// Must be overridden in `bootstrap()` using `sharedPrefsProvider.overrideWithValue(...)`
/// right before `runApp`.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPrefsProvider must be overridden in ProviderScope before use',
  );
});
