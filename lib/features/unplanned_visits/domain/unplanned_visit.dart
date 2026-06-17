import 'package:sales_sphere_erp/features/unplanned_visits/domain/visit_status.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/visit_target.dart';

// Re-export so consumers of an UnplannedVisit get VisitStatus / VisitTarget
// (and their extensions) for free.
export 'package:sales_sphere_erp/features/unplanned_visits/domain/visit_status.dart';
export 'package:sales_sphere_erp/features/unplanned_visits/domain/visit_target.dart';

/// A captured GPS leg of a visit (start or stop). Address is reverse-geocoded
/// best-effort and may be null.
class VisitLocation {
  const VisitLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? address;
}

/// UI-facing unplanned-visit model. Decoupled from the wire DTO so backend
/// renames don't ripple into widgets.
///
/// The server owns [id], the timestamps, and the computed [durationSeconds];
/// the client never fabricates them. A visit is made to exactly one
/// [target] (customer / prospect / site). The photo, [description] and
/// optional [followUpDate] are captured at stop time.
class UnplannedVisit {
  const UnplannedVisit({
    required this.id,
    required this.status,
    required this.target,
    this.startedAt,
    this.startLocation,
    this.stoppedAt,
    this.stopLocation,
    this.imageUrl,
    this.description,
    this.followUpDate,
    this.durationSeconds,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final VisitStatus status;
  final VisitTarget target;

  final DateTime? startedAt;
  final VisitLocation? startLocation;

  final DateTime? stoppedAt;
  final VisitLocation? stopLocation;

  /// Remote URL of the single odometer-style proof photo, captured at stop.
  final String? imageUrl;
  final String? description;

  /// Optional date the rep plans to revisit. Powers "Follow-ups" dashboards.
  final DateTime? followUpDate;

  /// Server-computed visit length in seconds; null until completed.
  final int? durationSeconds;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isInProgress => status.isInProgress;
  bool get isCompleted => status.isCompleted;
}
