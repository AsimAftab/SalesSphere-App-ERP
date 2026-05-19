/// Pre-defined leave categories. Comes from the bottom-sheet picker on
/// the add/edit form. Keep wire-encoded as the enum name (lowercase
/// camel-cased) so the backend doesn't get a localised display string.
enum LeaveCategory {
  sick,
  maternity,
  paternity,
  compassionate,
  religious,
  familyResponsibility,
  others,
}

/// Workflow status of a leave request. Drives the list filter chip and
/// the per-row status badge. The list page also uses this to decide
/// whether the detail page should open editable or read-only — only
/// `pending` requests are user-mutable.
enum LeaveStatus { pending, approved, rejected }

/// UI-facing leave-request model. Decoupled from wire DTOs so backend
/// renames don't ripple into widgets. Will be promoted to freezed once
/// the leaves API + drift table land.
///
/// `endDate` is optional — a same-day leave (e.g. one-day sick leave)
/// has `startDate` set and `endDate == null`. The list/detail pages
/// render that as just the start date instead of `start - end`.
class Leave {
  const Leave({
    required this.id,
    required this.category,
    required this.startDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.endDate,
  });

  final String id;
  final LeaveCategory category;

  final DateTime startDate;
  final DateTime? endDate;

  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;
}

/// Display label for a category, used by the picker and the list-card
/// heading. Lives next to the enum so adding a new variant forces this
/// switch to update at compile time.
///
/// Note: no `Leave` suffix — the page already says "Leave Requests" in
/// its header and section title, so repeating it on every card just
/// adds noise.
String leaveCategoryLabel(LeaveCategory c) => switch (c) {
  LeaveCategory.sick => 'Sick',
  LeaveCategory.maternity => 'Maternity',
  LeaveCategory.paternity => 'Paternity',
  LeaveCategory.compassionate => 'Compassionate',
  LeaveCategory.religious => 'Religious Holiday',
  LeaveCategory.familyResponsibility => 'Family Responsibility',
  LeaveCategory.others => 'Miscellaneous/Others',
};

/// Inclusive day count between [start] and [end], or `1` when [end] is
/// null (single-day leave). The leave on Apr 12 → Apr 12 is 1 day, not
/// 0 — the user counts the day they're absent, not the gap between
/// the two endpoints.
int leaveDayCount(DateTime start, DateTime? end) {
  if (end == null) return 1;
  return end.difference(start).inDays + 1;
}

/// Pluralised display ("1 day" / "5 days") for the duration field on
/// the add/edit forms. Returns an empty string when [start] is null
/// (form not filled yet).
String leaveDurationLabel(DateTime? start, DateTime? end) {
  if (start == null) return '';
  final days = leaveDayCount(start, end);
  return days == 1 ? '1 day' : '$days days';
}

/// Display label for the status badge.
String leaveStatusLabel(LeaveStatus s) => switch (s) {
  LeaveStatus.pending => 'Pending',
  LeaveStatus.approved => 'Approved',
  LeaveStatus.rejected => 'Rejected',
};
