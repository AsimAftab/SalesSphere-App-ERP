import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Thin facade over [Geolocator] so the LocationPicker can be
/// unit-tested without hitting platform channels. Methods do not throw
/// for the common "denied" / "service disabled" paths — they surface
/// state via the return value (null position, or an explicit
/// [LocationPermission] enum) and let the caller render UX.
class LocationService {
  const LocationService();

  /// Returns the active permission status after running through the
  /// request flow once if it was [LocationPermission.denied]. Caller
  /// must still check the returned value before calling
  /// [getCurrentLocation] — `deniedForever` cannot be undone in-app.
  Future<LocationPermission> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Best-effort current position. Returns `null` if permission is
  /// missing, location services are off, or the platform throws.
  Future<Position?> getCurrentLocation() async {
    final permission = await ensurePermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition();
    } on Exception catch (_) {
      return null;
    }
  }

  /// Opens the system per-app settings page (used when permission has
  /// been permanently denied — we can't re-prompt from the app).
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

final locationServiceProvider = Provider<LocationService>(
  (_) => const LocationService(),
);
