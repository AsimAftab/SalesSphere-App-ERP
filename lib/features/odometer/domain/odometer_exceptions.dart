/// `409` conflicts where the client's view of today is stale relative to the
/// server: a trip is already open when starting, or none is open when
/// stopping. The UI should toast [message] and refresh today's status rather
/// than optimistically mutating local state.
class OdometerConflictException implements Exception {
  const OdometerConflictException(this.message, {required this.code});

  final String message;

  /// `ODOMETER_TRIP_IN_PROGRESS` | `ODOMETER_NO_ACTIVE_TRIP`.
  final String code;

  @override
  String toString() => 'OdometerConflictException($code): $message';
}

/// `422 NOT_CHECKED_IN`: the backend refuses to start a trip because the rep
/// hasn't marked attendance for the day. The rep can fix this directly, so the
/// UI surfaces [message] and offers to jump to the attendance check-in screen.
class OdometerNotCheckedInException implements Exception {
  const OdometerNotCheckedInException(this.message);

  final String message;

  @override
  String toString() => 'OdometerNotCheckedInException: $message';
}
