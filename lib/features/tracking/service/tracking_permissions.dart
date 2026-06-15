import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of the pre-tracking permission flow. [granted] gates whether
/// tracking can start at all (location service on + foreground location).
/// [backgroundGranted] tells the UI whether to nudge the rep about
/// kill-resilience (background location / battery exemption).
class TrackingPermissionResult {
  const TrackingPermissionResult({
    required this.granted,
    this.backgroundGranted = false,
    this.message,
  });

  final bool granted;
  final bool backgroundGranted;
  final String? message;
}

/// Runs the permission gauntlet before a tracking session: location services
/// enabled → foreground location → background location (`locationAlways`) →
/// notifications (Android 13+) → battery-optimisation exemption (best-effort).
/// Only the first two are hard requirements; the rest degrade gracefully but
/// matter for tracking that survives the app being swiped away.
class TrackingPermissions {
  const TrackingPermissions();

  Future<TrackingPermissionResult> ensureForTracking() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const TrackingPermissionResult(
        granted: false,
        message: 'Turn on location services to start tracking.',
      );
    }

    final location = await Permission.location.request();
    if (!location.isGranted) {
      return const TrackingPermissionResult(
        granted: false,
        message: 'Location permission is required to track your beat plan.',
      );
    }

    // Background location keeps streaming when the app is swiped away.
    final background = await Permission.locationAlways.request();

    // Android 13+ runtime notification permission for the ongoing notification.
    await Permission.notification.request();

    // Best-effort: exempt from battery optimisation so the OS is less likely
    // to kill the foreground service. Never blocks starting.
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    return TrackingPermissionResult(
      granted: true,
      backgroundGranted: background.isGranted,
      message: background.isGranted
          ? null
          : 'Allow location "all the time" so tracking continues when the app '
              'is closed.',
    );
  }
}

final trackingPermissionsProvider = Provider<TrackingPermissions>(
  (_) => const TrackingPermissions(),
);
