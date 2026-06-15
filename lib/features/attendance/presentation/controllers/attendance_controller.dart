import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/core/utils/geo_distance.dart';
import 'package:sales_sphere_erp/core/utils/reverse_geocode.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/geofence_config.dart';
// Providers file re-exports `attendanceRepositoryProvider` so the
// controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';

part 'attendance_controller.g.dart';

/// Routes attendance write actions from the UI through the repository.
/// Reads stay on `attendanceMonthProvider`, `attendanceByDateProvider`,
/// `attendanceTodayStatusProvider`, and `todayAttendanceProvider`.
///
/// Both writes capture the device location (the backend requires
/// coordinates + a non-empty address) and enforce the org geofence when it's
/// active — see [_resolveLocation]. Each opens a `ref.keepAlive()` link for
/// the duration of its in-flight `await` and closes it in `finally`, so the
/// notifier stays valid through the post-await `ref.invalidate(...)` without
/// permanently pinning a write-only controller in memory.
@riverpod
class AttendanceController extends _$AttendanceController {
  @override
  void build() {}

  Future<AttendanceRecord> checkIn() async {
    final link = ref.keepAlive();
    try {
      final loc = await _resolveLocation();
      final now = DateTime.now();
      final created = await ref.read(attendanceRepositoryProvider).checkIn(
            latitude: loc.latitude,
            longitude: loc.longitude,
            address: loc.address,
          );
      _invalidateReads(now);
      return created;
    } finally {
      link.close();
    }
  }

  Future<AttendanceRecord> checkOut({required bool isHalfDay}) async {
    final link = ref.keepAlive();
    try {
      final loc = await _resolveLocation();
      final now = DateTime.now();
      final updated = await ref.read(attendanceRepositoryProvider).checkOut(
            latitude: loc.latitude,
            longitude: loc.longitude,
            address: loc.address,
            isHalfDay: isHalfDay,
          );
      _invalidateReads(now);
      return updated;
    } finally {
      link.close();
    }
  }

  /// Captures the device location and enforces the geofence. The backend
  /// requires coordinates + a non-empty address, so a missing fix is a hard
  /// stop ([LocationUnavailableException]) rather than the old best-effort
  /// null. When the org's geofence is active and the user is beyond
  /// [kAttendanceGeofenceRadiusMeters], throws [OutsideGeofenceException].
  Future<({double latitude, double longitude, String address})>
      _resolveLocation() async {
    final status = await ref.read(attendanceTodayStatusProvider.future);
    final position =
        await ref.read(locationServiceProvider).getCurrentLocation();
    if (position == null) throw const LocationUnavailableException();

    final geo = status.geofence;
    if (geo.isActive) {
      final distance = haversineMeters(
        position.latitude,
        position.longitude,
        geo.latitude!,
        geo.longitude!,
      );
      if (distance > kAttendanceGeofenceRadiusMeters) {
        throw OutsideGeofenceException(
          distanceMeters: distance,
          radiusMeters: kAttendanceGeofenceRadiusMeters,
        );
      }
    }

    // Reverse-geocode for a readable address; fall back to coordinates so the
    // required `address` field is never empty.
    final address =
        await reverseGeocodeAddress(position.latitude, position.longitude) ??
            '${position.latitude.toStringAsFixed(5)}, '
                '${position.longitude.toStringAsFixed(5)}';

    return (
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
    );
  }

  void _invalidateReads(DateTime now) {
    ref
      ..invalidate(attendanceTodayStatusProvider)
      ..invalidate(attendanceMonthlyReportProvider(now.year, now.month));
  }
}
