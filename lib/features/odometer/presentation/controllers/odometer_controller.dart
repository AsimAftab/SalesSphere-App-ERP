import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/core/utils/reverse_geocode.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
// Providers file re-exports `odometerRepositoryProvider` so the controller
// stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/odometer/presentation/providers/odometer_providers.dart';

part 'odometer_controller.g.dart';

/// Routes odometer write actions (start / stop / delete) from the UI through
/// the repository. Reads stay on `odometerTodayStatusProvider`,
/// `odometerMonthlyReportProvider`, and `odometerTripByIdProvider`.
///
/// Each write opens a `ref.keepAlive()` link for the duration of its in-flight
/// `await` and closes it in `finally`, so the notifier stays valid through the
/// post-await `ref.invalidate(...)` without permanently pinning a write-only
/// controller in memory (same shape as `AttendanceController`).
@riverpod
class OdometerController extends _$OdometerController {
  @override
  void build() {}

  Future<OdometerTrip> startTrip({
    required double startReading,
    required DistanceUnit unit,
    String? description,
    String? imagePath,
  }) async {
    final link = ref.keepAlive();
    try {
      final loc = await _resolveLocation();
      final now = DateTime.now();
      final created = await ref.read(odometerRepositoryProvider).startTrip(
            startReading: startReading,
            unit: unit,
            description: description,
            latitude: loc?.latitude,
            longitude: loc?.longitude,
            address: loc?.address,
            imagePath: imagePath,
          );
      _invalidateReads(now);
      return created;
    } finally {
      link.close();
    }
  }

  Future<OdometerTrip> stopTrip({
    required double stopReading,
    required DistanceUnit unit,
    String? description,
    String? imagePath,
  }) async {
    final link = ref.keepAlive();
    try {
      final loc = await _resolveLocation();
      final now = DateTime.now();
      final completed = await ref.read(odometerRepositoryProvider).stopTrip(
            stopReading: stopReading,
            unit: unit,
            description: description,
            latitude: loc?.latitude,
            longitude: loc?.longitude,
            address: loc?.address,
            imagePath: imagePath,
          );
      _invalidateReads(now);
      return completed;
    } finally {
      link.close();
    }
  }

  Future<void> deleteTrip(String id, {DateTime? tripDate}) async {
    final link = ref.keepAlive();
    try {
      await ref.read(odometerRepositoryProvider).deleteTrip(id);
      final now = DateTime.now();
      _invalidateReads(now);
      // Refresh the month the trip belonged to too, if it wasn't this month.
      if (tripDate != null &&
          (tripDate.year != now.year || tripDate.month != now.month)) {
        ref.invalidate(
          odometerMonthlyReportProvider(tripDate.year, tripDate.month),
        );
      }
      ref.invalidate(odometerTripByIdProvider(id));
    } finally {
      link.close();
    }
  }

  /// Best-effort location capture. Unlike attendance (which hard-requires a
  /// fix), odometer coordinates are optional — a missing fix or a failed
  /// reverse-geocode just sends nulls rather than blocking the trip.
  Future<({double latitude, double longitude, String? address})?>
      _resolveLocation() async {
    final position =
        await ref.read(locationServiceProvider).getCurrentLocation();
    if (position == null) return null;
    final address =
        await reverseGeocodeAddress(position.latitude, position.longitude);
    return (
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
    );
  }

  void _invalidateReads(DateTime now) {
    ref
      ..invalidate(odometerTodayStatusProvider)
      ..invalidate(odometerMonthlyReportProvider(now.year, now.month));
  }
}
