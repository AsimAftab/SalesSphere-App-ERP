import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';

/// `data` of `GET /odometer/my-monthly-report` — the month's trips plus a
/// server-computed summary. Totals are always expressed in km (the backend
/// converts miles legs at 1 mi = 1.60934 km).
class OdometerMonthlyReport {
  const OdometerMonthlyReport({
    required this.month,
    required this.year,
    required this.records,
    required this.summary,
  });

  final int month;
  final int year;

  /// Trips ordered by date then tripNumber ascending.
  final List<OdometerTrip> records;
  final OdometerMonthlySummary summary;
}

class OdometerMonthlySummary {
  const OdometerMonthlySummary({
    required this.totalDistance,
    required this.distanceUnit,
    required this.totalTrips,
    required this.tripsCompleted,
    required this.tripsInProgress,
    required this.avgDistancePerTrip,
  });

  /// Total distance across the month, in [distanceUnit] (always `km`).
  final double totalDistance;
  final String distanceUnit;
  final int totalTrips;
  final int tripsCompleted;
  final int tripsInProgress;
  final int avgDistancePerTrip;

  static const empty = OdometerMonthlySummary(
    totalDistance: 0,
    distanceUnit: 'km',
    totalTrips: 0,
    tripsCompleted: 0,
    tripsInProgress: 0,
    avgDistancePerTrip: 0,
  );
}
