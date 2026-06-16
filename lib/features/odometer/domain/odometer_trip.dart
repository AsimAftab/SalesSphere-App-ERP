import 'package:sales_sphere_erp/features/odometer/domain/odometer_status.dart';
import 'package:sales_sphere_erp/features/odometer/domain/trip_location.dart';

// Re-export so consumers of an OdometerTrip get DistanceUnit / OdometerStatus
// (and their `.label` / `.isInProgress` extensions) for free.
export 'package:sales_sphere_erp/features/odometer/domain/odometer_status.dart';
export 'package:sales_sphere_erp/features/odometer/domain/trip_location.dart';

/// UI-facing odometer trip. Mirrors the backend `OdometerRecord`: the server
/// owns [id], [tripNumber], [date], the start/stop timestamps, and the
/// computed [distance] — the client never fabricates them.
///
/// Readings are doubles (the backend stores Float; e.g. `15025.5`). A single
/// [distanceUnit] is carried for display; the stop leg is always recorded in
/// the same unit as the start.
class OdometerTrip {
  const OdometerTrip({
    required this.id,
    required this.tripNumber,
    required this.status,
    required this.distanceUnit,
    this.employeeId,
    this.date,
    this.startReading,
    this.startImageUrl,
    this.startDescription,
    this.startedAt,
    this.startLocation,
    this.stopReading,
    this.stopImageUrl,
    this.stopDescription,
    this.stoppedAt,
    this.stopLocation,
    this.distance,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? employeeId;

  /// Org-timezone calendar day (y/m/d only) the trip belongs to.
  final DateTime? date;

  /// 1-based index of the trip within (org, employee, date), server-assigned.
  final int tripNumber;
  final OdometerStatus status;
  final DistanceUnit distanceUnit;

  final double? startReading;
  final String? startImageUrl;
  final String? startDescription;
  final DateTime? startedAt;
  final TripLocation? startLocation;

  final double? stopReading;
  final String? stopImageUrl;
  final String? stopDescription;
  final DateTime? stoppedAt;
  final TripLocation? stopLocation;

  /// `stopReading − startReading`, computed by the server; null until the trip
  /// is completed.
  final double? distance;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isInProgress => status.isInProgress;
  bool get isCompleted => status.isCompleted;

  OdometerTrip copyWith({
    String? id,
    String? employeeId,
    DateTime? date,
    int? tripNumber,
    OdometerStatus? status,
    DistanceUnit? distanceUnit,
    double? startReading,
    String? startImageUrl,
    String? startDescription,
    DateTime? startedAt,
    TripLocation? startLocation,
    double? stopReading,
    String? stopImageUrl,
    String? stopDescription,
    DateTime? stoppedAt,
    TripLocation? stopLocation,
    double? distance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OdometerTrip(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      tripNumber: tripNumber ?? this.tripNumber,
      status: status ?? this.status,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      startReading: startReading ?? this.startReading,
      startImageUrl: startImageUrl ?? this.startImageUrl,
      startDescription: startDescription ?? this.startDescription,
      startedAt: startedAt ?? this.startedAt,
      startLocation: startLocation ?? this.startLocation,
      stopReading: stopReading ?? this.stopReading,
      stopImageUrl: stopImageUrl ?? this.stopImageUrl,
      stopDescription: stopDescription ?? this.stopDescription,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      stopLocation: stopLocation ?? this.stopLocation,
      distance: distance ?? this.distance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
