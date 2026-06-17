import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';

/// `data` of `GET /odometer/status/today` — the signed-in rep's trips for the
/// org's current calendar day, plus the active-trip flag. Drives the home
/// page's status badge, active-trip card, and today's carousel.
class OdometerTodayStatus {
  const OdometerTodayStatus({
    required this.trips,
    required this.hasActiveTrip,
    this.activeTripId,
  });

  /// Today's trips, ordered by `tripNumber` ascending.
  final List<OdometerTrip> trips;
  final bool hasActiveTrip;
  final String? activeTripId;

  /// The open (`in_progress`) trip, if any.
  OdometerTrip? get activeTrip {
    for (final t in trips) {
      if (t.isInProgress) return t;
    }
    return null;
  }

  /// Today's finished trips.
  List<OdometerTrip> get completedTrips =>
      trips.where((t) => t.isCompleted).toList(growable: false);
}
