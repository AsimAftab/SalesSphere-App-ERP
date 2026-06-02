/// Workflow status of a tour-plan request. Mirrors `LeaveStatus` so the
/// list filter chip and per-row status badge read as the same family
/// across the field-ops modules. Drives whether the detail page opens
/// editable or read-only — only `pending` plans are user-mutable.
enum TourPlanStatus { pending, approved, rejected, completed }

/// UI-facing tour-plan model. Decoupled from wire DTOs so backend
/// renames don't ripple into widgets. Will be promoted to freezed once
/// the tour-plans API + drift table land.
///
/// Unlike leaves, `endDate` is required — a tour plan always covers a
/// defined window even when the start and end fall on the same day.
class TourPlan {
  const TourPlan({
    required this.id,
    required this.placeOfVisit,
    required this.startDate,
    required this.endDate,
    required this.purpose,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  final String id;

  final String placeOfVisit;

  final DateTime startDate;
  final DateTime endDate;

  final String purpose;
  final TourPlanStatus status;
  final DateTime createdAt;

  /// Reason for rejection (only present if status is rejected).
  final String? rejectionReason;
}

/// Inclusive day count between [start] and [end]. Apr 12 → Apr 12 is
/// 1 day, not 0 — the user counts the day they're on tour, not the gap
/// between the two endpoints.
int tourPlanDayCount(DateTime start, DateTime end) {
  return end.difference(start).inDays + 1;
}

/// Pluralised display ("1 day" / "5 days") for the duration field on
/// the add/edit forms. Returns an empty string when either end of the
/// range is missing (form not filled yet).
String tourPlanDurationLabel(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '';
  final days = tourPlanDayCount(start, end);
  return days == 1 ? '1 day' : '$days days';
}

/// Display label for the status badge.
String tourPlanStatusLabel(TourPlanStatus s) => switch (s) {
  TourPlanStatus.pending => 'Pending',
  TourPlanStatus.approved => 'Approved',
  TourPlanStatus.rejected => 'Rejected',
  TourPlanStatus.completed => 'Completed',
};
