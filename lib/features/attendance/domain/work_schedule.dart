import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Result of a check-in time-window evaluation.
enum CheckInWindowStatus {
  /// Current time is before [WorkSchedule.checkInAllowedFrom] —
  /// the button should be disabled with a hint.
  tooEarly,

  /// Current time is inside the allowed window — check-in is permitted.
  allowed,

  /// Current time is past [WorkSchedule.checkInAllowedUntil] —
  /// check-in is no longer permitted; show the info dialog.
  tooLate,
}

/// Result of a checkout time-window evaluation.
enum CheckOutWindowStatus {
  /// Neither the full-day nor half-day checkout window is open yet.
  tooEarly,

  /// The half-day checkout window is currently open.
  halfDayAllowed,

  /// The full-day checkout window is open (≥ scheduledCheckOut − 30 min).
  fullDayAllowed,
}

/// Organisation shift configuration and time-window helpers.
///
/// Window rules:
///   Check-in:         [scheduledCheckIn − 2 h,  scheduledCheckIn + 30 min]
///   Full-day checkout:[scheduledCheckOut − 30 min, ∞)
///   Half-day checkout:[scheduledHalfDayCheckOut − 15 min,
///                      scheduledHalfDayCheckOut + 30 min]
class WorkSchedule {
  const WorkSchedule({
    required this.scheduledCheckIn,
    required this.scheduledCheckOut,
    required this.scheduledHalfDayCheckOut,
    required this.weeklyOffDays,
    this.enforceWindows = true,
  });

  /// When false, the check-in/out time windows are not gated client-side —
  /// [checkInStatus] is always `allowed` and [checkOutStatus] always
  /// `fullDayAllowed`. Set when the org hasn't configured its shift times
  /// (or they're unparseable), so the server stays the authority and its
  /// rejection messages surface instead of the app guessing. [weeklyOffDays]
  /// still applies regardless.
  final bool enforceWindows;

  /// Scheduled start of the work day (e.g. 09:30).
  final TimeOfDay scheduledCheckIn;

  /// Scheduled full-day checkout time (e.g. 18:00).
  final TimeOfDay scheduledCheckOut;

  /// Scheduled half-day checkout time (e.g. 13:00).
  final TimeOfDay scheduledHalfDayCheckOut;

  /// ISO weekday integers (1 = Monday … 7 = Sunday) that are weekly offs.
  final Set<int> weeklyOffDays;

  // ── private helpers ────────────────────────────────────────────────────

  DateTime _dt(DateTime date, TimeOfDay tod) =>
      DateTime(date.year, date.month, date.day, tod.hour, tod.minute);

  // ── public window boundaries ───────────────────────────────────────────

  bool isWeeklyOff(DateTime date) => weeklyOffDays.contains(date.weekday);

  /// Earliest moment the Check-In button becomes active.
  DateTime checkInAllowedFrom(DateTime date) =>
      _dt(date, scheduledCheckIn).subtract(const Duration(hours: 2));

  /// Latest moment check-in is still permitted.
  DateTime checkInAllowedUntil(DateTime date) =>
      _dt(date, scheduledCheckIn).add(const Duration(minutes: 30));

  /// Earliest moment full-day checkout is permitted.
  DateTime fullDayCheckOutAllowedFrom(DateTime date) =>
      _dt(date, scheduledCheckOut).subtract(const Duration(minutes: 30));

  /// Earliest moment half-day checkout is permitted.
  DateTime halfDayCheckOutAllowedFrom(DateTime date) =>
      _dt(date, scheduledHalfDayCheckOut).subtract(const Duration(minutes: 15));

  /// Latest moment half-day checkout is still permitted.
  DateTime halfDayCheckOutAllowedUntil(DateTime date) =>
      _dt(date, scheduledHalfDayCheckOut).add(const Duration(minutes: 30));

  // ── status evaluators ──────────────────────────────────────────────────

  /// Evaluates check-in permission at [now].
  /// Does NOT account for weekly-off — callers handle that separately so
  /// the dialog can show the right copy.
  CheckInWindowStatus checkInStatus(DateTime now) {
    if (!enforceWindows) return CheckInWindowStatus.allowed;
    final date = DateTime(now.year, now.month, now.day);
    if (now.isBefore(checkInAllowedFrom(date))) return CheckInWindowStatus.tooEarly;
    if (now.isAfter(checkInAllowedUntil(date))) return CheckInWindowStatus.tooLate;
    return CheckInWindowStatus.allowed;
  }

  /// Evaluates checkout permission at [now].
  /// Full-day takes precedence: once that window opens, half-day is moot.
  CheckOutWindowStatus checkOutStatus(DateTime now) {
    if (!enforceWindows) return CheckOutWindowStatus.fullDayAllowed;
    final date = DateTime(now.year, now.month, now.day);
    if (!now.isBefore(fullDayCheckOutAllowedFrom(date))) {
      return CheckOutWindowStatus.fullDayAllowed;
    }
    final hdFrom = halfDayCheckOutAllowedFrom(date);
    final hdUntil = halfDayCheckOutAllowedUntil(date);
    if (!now.isBefore(hdFrom) && !now.isAfter(hdUntil)) {
      return CheckOutWindowStatus.halfDayAllowed;
    }
    return CheckOutWindowStatus.tooEarly;
  }

  // ── formatting helpers ─────────────────────────────────────────────────

  /// Formats a [TimeOfDay] as `h:mm a` (e.g., 1:00 PM).
  String formatTod(TimeOfDay tod) {
    final dt = DateTime(2000, 1, 1, tod.hour, tod.minute);
    return DateFormat('h:mm a').format(dt);
  }

  /// Formats a [DateTime] as `h:mm a` (e.g., 1:00 PM).
  String formatDt(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  /// Human-readable name for an ISO weekday number (1 = Monday … 7 = Sunday).
  static String weekdayName(int isoWeekday) => const <String>[
        '',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][isoWeekday];
}
