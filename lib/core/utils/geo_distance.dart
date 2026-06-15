import 'dart:math';

/// Default geofence radius (metres) for a beat-plan stop check-in. A rep must
/// be within this distance of a stop to start its visit.
const double kGeofenceRadiusMeters = 50;

/// Great-circle distance between two WGS-84 lat/lng points, in **metres**,
/// via the Haversine formula. Accurate to well within a metre at city scale —
/// more than enough for a 50 m geofence — and dependency-free so it stays
/// pure-Dart and unit-testable (no platform channel like
/// `Geolocator.distanceBetween`).
double haversineMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusM = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final sinLat = sin(dLat / 2);
  final sinLng = sin(dLng / 2);
  final a = sinLat * sinLat +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sinLng * sinLng;
  return earthRadiusM * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * pi / 180.0;
