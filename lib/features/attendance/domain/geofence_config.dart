/// Client geofence radius (metres) for attendance check-in/out, matching the
/// v1 app's attendance radius. The backend sends the anchor + enabled flag on
/// `GET /attendance/status/today` but never enforces distance — the app gates
/// within this radius. (Beat-plan stop check-ins use a tighter 50 m via
/// `kGeofenceRadiusMeters`.)
const double kAttendanceGeofenceRadiusMeters = 100;

/// Org attendance-geofence configuration from `GET /attendance/status/today`.
/// The anchor (office/branch coordinates) is optional — geofencing only gates
/// when it's both [enabled] and an anchor is present (see [isActive]).
class GeofenceConfig {
  const GeofenceConfig({
    required this.enabled,
    this.latitude,
    this.longitude,
    this.address,
    this.googleMapLink,
  });

  /// Geofencing off, no anchor — the safe default while loading or when the
  /// org hasn't configured it.
  static const disabled = GeofenceConfig(enabled: false);

  final bool enabled;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? googleMapLink;

  /// Gate check-in/out only when the org turned geofencing on AND an anchor
  /// is available to measure against. If enabled but the anchor is missing,
  /// there's nothing to gate against, so we don't block.
  bool get isActive => enabled && latitude != null && longitude != null;
}
