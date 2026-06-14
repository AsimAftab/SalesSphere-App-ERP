/// Per-month roll-up shown on the home page's "Monthly Summary" card.
/// Derived synchronously from the month's `AttendanceRecord` list —
/// see `attendanceMonthlySummaryProvider`.
class MonthlySummary {
  const MonthlySummary({
    required this.present,
    required this.absent,
    required this.leave,
    required this.halfDay,
    required this.weeklyOff,
    required this.late,
    required this.attendancePct,
  });

  /// All-zeros instance used as the "still loading" placeholder so the
  /// summary card never reads as a runtime failure.
  static const empty = MonthlySummary(
    present: 0,
    absent: 0,
    leave: 0,
    halfDay: 0,
    weeklyOff: 0,
    late: 0,
    attendancePct: 0,
  );

  final int present;
  final int absent;
  final int leave;
  final int halfDay;
  final int weeklyOff;

  /// Count of present days where check-in was late. Overlaps [present]
  /// (a late day is still a present day), mirroring the server tally.
  final int late;

  /// Percent attendance in the 0–100 range. Half-day counts as 0.5
  /// of a working day; weekly-offs are excluded from the denominator.
  final double attendancePct;
}
