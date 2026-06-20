import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';

/// `data` of `GET /unplanned-visits/my-monthly-report` — the month's visits
/// plus a summary. Mirrors the odometer monthly report so the history page
/// and home summary card read the same shape across both features.
///
/// NOTE: the backend endpoint does not exist yet. Until it ships, the
/// repository assembles this client-side from `status/today` (see
/// `UnplannedVisitRepositoryImpl.getMonthlyReport`). Swapping to the real
/// endpoint is a one-method change.
class UnplannedVisitsMonthlyReport {
  const UnplannedVisitsMonthlyReport({
    required this.month,
    required this.year,
    required this.records,
    required this.summary,
  });

  final int month;
  final int year;

  /// The month's visits, newest-first.
  final List<UnplannedVisit> records;
  final UnplannedVisitsMonthlySummary summary;
}

/// Headline counts for a month of unplanned visits — powers the home summary
/// card's stat tiles.
class UnplannedVisitsMonthlySummary {
  const UnplannedVisitsMonthlySummary({
    required this.totalVisits,
    required this.visitsCompleted,
    required this.visitsInProgress,
    required this.followUps,
  });

  final int totalVisits;
  final int visitsCompleted;
  final int visitsInProgress;

  /// Visits with a follow-up date set — the rep's planned revisits.
  final int followUps;

  static const empty = UnplannedVisitsMonthlySummary(
    totalVisits: 0,
    visitsCompleted: 0,
    visitsInProgress: 0,
    followUps: 0,
  );

  /// Derives the counts from a list of visits. Used by the client-side stub
  /// today; the server will compute these once the endpoint lands.
  factory UnplannedVisitsMonthlySummary.fromVisits(List<UnplannedVisit> v) {
    var completed = 0;
    var inProgress = 0;
    var followUps = 0;
    for (final visit in v) {
      if (visit.isCompleted) completed++;
      if (visit.isInProgress) inProgress++;
      if (visit.followUpDate != null) followUps++;
    }
    return UnplannedVisitsMonthlySummary(
      totalVisits: v.length,
      visitsCompleted: completed,
      visitsInProgress: inProgress,
      followUps: followUps,
    );
  }
}
