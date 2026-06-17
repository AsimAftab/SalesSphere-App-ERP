import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';

/// `data` of `GET /unplanned-visits/status/today` — the signed-in rep's visits
/// for the org's current calendar day, plus the active-visit flag. Drives the
/// home page's status badge, active-visit card, and today's list.
class UnplannedVisitsToday {
  const UnplannedVisitsToday({
    required this.visits,
    required this.hasActiveVisit,
    this.activeVisitId,
  });

  /// Today's visits, ordered newest-first.
  final List<UnplannedVisit> visits;
  final bool hasActiveVisit;
  final String? activeVisitId;

  /// The open (`in_progress`) visit, if any. A rep has at most one.
  UnplannedVisit? get activeVisit {
    for (final v in visits) {
      if (v.isInProgress) return v;
    }
    return null;
  }

  /// Today's finished visits.
  List<UnplannedVisit> get completedVisits =>
      visits.where((v) => v.isCompleted).toList(growable: false);
}
