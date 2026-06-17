import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/core/utils/geo_distance.dart';
import 'package:sales_sphere_erp/core/utils/reverse_geocode.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit_exceptions.dart';
// Providers file re-exports `unplannedVisitRepositoryProvider` so the
// controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/providers/unplanned_visit_providers.dart';

part 'unplanned_visit_controller.g.dart';

/// Routes unplanned-visit write actions (start / stop / delete) from the UI
/// through the repository. Reads stay on `unplannedVisitsTodayProvider` and
/// `unplannedVisitByIdProvider`.
///
/// Each write opens a `ref.keepAlive()` link for the duration of its in-flight
/// `await` and closes it in `finally`, so the notifier stays valid through the
/// post-await `ref.invalidate(...)` without permanently pinning a write-only
/// controller in memory (same shape as `OdometerController`).
@riverpod
class UnplannedVisitController extends _$UnplannedVisitController {
  @override
  void build() {}

  /// Starts a visit to [target]. Enforces the 50 m geofence: when the target
  /// has coordinates, a GPS fix is required and must be within range — a
  /// missing fix throws [LocationUnavailableException] and being too far
  /// throws [VisitOutOfRangeException]. Targets without coordinates skip the
  /// gate (there's nothing to measure against) and start with best-effort GPS.
  Future<UnplannedVisit> startVisit(VisitTarget target) async {
    final link = ref.keepAlive();
    try {
      final position =
          await ref.read(locationServiceProvider).getCurrentLocation();

      if (target.hasLocation) {
        if (position == null) throw const LocationUnavailableException();
        final distance = haversineMeters(
          position.latitude,
          position.longitude,
          target.latitude!,
          target.longitude!,
        );
        if (distance > kGeofenceRadiusMeters) {
          throw VisitOutOfRangeException(
            distanceMeters: distance,
            radiusMeters: kGeofenceRadiusMeters,
            targetName: target.displayName,
          );
        }
      }

      final address = position == null
          ? null
          : await reverseGeocodeAddress(
                  position.latitude, position.longitude) ??
              '${position.latitude.toStringAsFixed(5)}, '
                  '${position.longitude.toStringAsFixed(5)}';

      final created =
          await ref.read(unplannedVisitRepositoryProvider).startVisit(
                targetType: target.type,
                targetId: target.id,
                latitude: position?.latitude,
                longitude: position?.longitude,
                address: address,
              );
      _invalidateReads();
      return created;
    } finally {
      link.close();
    }
  }

  /// Completes the rep's open visit with the proof photo + optional notes /
  /// follow-up date. No geofence at stop — the rep may leave before logging.
  Future<UnplannedVisit> stopVisit({
    required String imagePath,
    String? description,
    DateTime? followUpDate,
  }) async {
    final link = ref.keepAlive();
    try {
      final position =
          await ref.read(locationServiceProvider).getCurrentLocation();
      final address = position == null
          ? null
          : await reverseGeocodeAddress(
                  position.latitude, position.longitude) ??
              '${position.latitude.toStringAsFixed(5)}, '
                  '${position.longitude.toStringAsFixed(5)}';

      final completed =
          await ref.read(unplannedVisitRepositoryProvider).stopVisit(
                imagePath: imagePath,
                description: description,
                followUpDate: followUpDate,
                latitude: position?.latitude,
                longitude: position?.longitude,
                address: address,
              );
      _invalidateReads();
      return completed;
    } finally {
      link.close();
    }
  }

  Future<void> deleteVisit(String id) async {
    final link = ref.keepAlive();
    try {
      await ref.read(unplannedVisitRepositoryProvider).deleteVisit(id);
      _invalidateReads();
      ref.invalidate(unplannedVisitByIdProvider(id));
    } finally {
      link.close();
    }
  }

  void _invalidateReads() {
    ref.invalidate(unplannedVisitsTodayProvider);
  }
}
