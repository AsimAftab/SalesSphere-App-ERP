/// Server-driven attendance restriction errors, parsed from the backend's
/// structured `error.code` + `error.details` (see the attendance API
/// contract). The check-in/out flow reacts to these instead of re-deriving
/// the org time windows on the client.
library;

/// Why the server refused a check-in.
enum CheckInDeniedReason { tooEarly, windowClosed, weeklyOff, onLeave, unknown }

CheckInDeniedReason _checkInReason(String? raw) {
  switch (raw) {
    case 'TOO_EARLY':
      return CheckInDeniedReason.tooEarly;
    case 'WINDOW_CLOSED':
      return CheckInDeniedReason.windowClosed;
    case 'WEEKLY_OFF':
      return CheckInDeniedReason.weeklyOff;
    case 'ON_LEAVE':
      return CheckInDeniedReason.onLeave;
    default:
      return CheckInDeniedReason.unknown;
  }
}

/// `422 ATTENDANCE_CHECKIN_RESTRICTED`. All times are `HH:mm` in the org TZ.
class CheckInRestrictionException implements Exception {
  const CheckInRestrictionException({
    required this.reason,
    this.allowedFrom,
    this.allowedUntil,
    this.scheduledCheckIn,
    this.weeklyOffDay,
    this.message,
  });

  factory CheckInRestrictionException.fromDetails(
    String? message,
    Map<String, dynamic> details,
  ) {
    return CheckInRestrictionException(
      reason: _checkInReason(details['reason'] as String?),
      allowedFrom: details['allowedFrom'] as String?,
      allowedUntil: details['allowedUntil'] as String?,
      scheduledCheckIn: details['scheduledCheckIn'] as String?,
      weeklyOffDay: details['weeklyOffDay'] as String?,
      message: message,
    );
  }

  final CheckInDeniedReason reason;
  final String? allowedFrom;
  final String? allowedUntil;
  final String? scheduledCheckIn;
  final String? weeklyOffDay;
  final String? message;
}

/// Why the server refused a check-out.
enum CheckOutDeniedReason {
  fullDayNotOpen,
  halfDayNotOpen,
  halfDayWindowClosed,
  windowClosed,
  unknown,
}

CheckOutDeniedReason _checkOutReason(String? raw) {
  switch (raw) {
    case 'FULL_DAY_NOT_OPEN':
      return CheckOutDeniedReason.fullDayNotOpen;
    case 'HALF_DAY_NOT_OPEN':
      return CheckOutDeniedReason.halfDayNotOpen;
    case 'HALF_DAY_WINDOW_CLOSED':
      return CheckOutDeniedReason.halfDayWindowClosed;
    case 'WINDOW_CLOSED':
      return CheckOutDeniedReason.windowClosed;
    default:
      return CheckOutDeniedReason.unknown;
  }
}

/// `422 ATTENDANCE_CHECKOUT_RESTRICTED`. When [canUseHalfDayFallback] is true,
/// the client should offer a half-day checkout (re-submit with isHalfDay).
class CheckOutRestrictionException implements Exception {
  const CheckOutRestrictionException({
    required this.reason,
    required this.canUseHalfDayFallback,
    this.fullDayAllowedFrom,
    this.scheduledCheckOut,
    this.halfDayAllowedFrom,
    this.halfDayClosedAt,
    this.scheduledHalfDayCheckOut,
    this.message,
  });

  factory CheckOutRestrictionException.fromDetails(
    String? message,
    Map<String, dynamic> details,
  ) {
    return CheckOutRestrictionException(
      reason: _checkOutReason(details['reason'] as String?),
      canUseHalfDayFallback:
          (details['canUseHalfDayFallback'] as bool?) ?? false,
      fullDayAllowedFrom: details['fullDayAllowedFrom'] as String?,
      scheduledCheckOut: details['scheduledCheckOut'] as String?,
      halfDayAllowedFrom: details['halfDayAllowedFrom'] as String?,
      halfDayClosedAt: details['halfDayClosedAt'] as String?,
      scheduledHalfDayCheckOut: details['scheduledHalfDayCheckOut'] as String?,
      message: message,
    );
  }

  final CheckOutDeniedReason reason;
  final bool canUseHalfDayFallback;
  final String? fullDayAllowedFrom;
  final String? scheduledCheckOut;
  final String? halfDayAllowedFrom;
  final String? halfDayClosedAt;
  final String? scheduledHalfDayCheckOut;
  final String? message;
}

/// `409` conflicts where the client's view of today is stale — already
/// checked in / out, or not checked in. The UI should refresh today's status.
class AttendanceConflictException implements Exception {
  const AttendanceConflictException(this.message, {required this.code});

  /// `ATTENDANCE_ALREADY_CHECKED_IN` | `ATTENDANCE_ALREADY_CHECKED_OUT` |
  /// `ATTENDANCE_NOT_CHECKED_IN`.
  final String code;
  final String message;
}
