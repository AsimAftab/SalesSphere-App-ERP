import 'package:sales_sphere_erp/core/utils/geo_distance.dart';

/// `409` conflicts where the client's view is stale — a visit is already open
/// when starting, or none is open when stopping. The UI should refresh today's
/// status and surface [message].
class UnplannedVisitConflictException implements Exception {
  const UnplannedVisitConflictException(this.message, {required this.code});

  /// `UNPLANNED_VISIT_IN_PROGRESS` | `UNPLANNED_VISIT_NO_ACTIVE`.
  final String code;
  final String message;
}

/// `422 NOT_CHECKED_IN`: the backend refuses to start a visit because the rep
/// hasn't marked attendance for the day. Unlike a stale-view conflict, the rep
/// can fix this directly — the UI surfaces [message] and offers to jump to the
/// attendance check-in screen.
///
/// A plain `Exception` (not an `ApiException`, which is `sealed`); the UI
/// catches it explicitly to show the check-in prompt.
class VisitNotCheckedInException implements Exception {
  const VisitNotCheckedInException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client-side geofence gate: the rep is farther than [radiusMeters] from the
/// selected target, so starting the visit is refused. The server doesn't
/// enforce this — the app does (matching attendance / beat-plan check-ins).
///
/// A plain `Exception` (not an `ApiException`, which is `sealed` and can't be
/// extended here); the UI catches it explicitly and shows [message].
class VisitOutOfRangeException implements Exception {
  VisitOutOfRangeException({
    required this.distanceMeters,
    required this.radiusMeters,
    required this.targetName,
  }) : message =
           "You're ${formatDistanceMeters(distanceMeters)} from $targetName. "
           'Move within ${radiusMeters.round()} m to start the visit.';

  final double distanceMeters;
  final double radiusMeters;
  final String targetName;
  final String message;

  @override
  String toString() => message;
}
