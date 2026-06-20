import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/unplanned_visits/data/repositories/unplanned_visit_repository_impl.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visits_monthly_report.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visits_today.dart';

// Re-export the repository provider so consumers (controller, tests) depend on
// the contract surface without importing from `data/`.
export 'package:sales_sphere_erp/features/unplanned_visits/data/repositories/unplanned_visit_repository_impl.dart'
    show unplannedVisitRepositoryProvider;

part 'unplanned_visit_providers.g.dart';

/// Today's visits + active-visit flag from `GET /unplanned-visits/status/today`.
/// Single source of truth for the home page's status, active-visit card, and
/// today's list.
@riverpod
Future<UnplannedVisitsToday> unplannedVisitsToday(Ref ref) async {
  return ref.watch(unplannedVisitRepositoryProvider).getTodayStatus();
}

/// The month's visits + summary. Powers the home summary card and the history
/// page. Backed by a client-side stub until the backend endpoint ships (see
/// `UnplannedVisitRepository.getMonthlyReport`).
@riverpod
Future<UnplannedVisitsMonthlyReport> unplannedVisitsMonthlyReport(
  Ref ref,
  int year,
  int month,
) async {
  return ref
      .watch(unplannedVisitRepositoryProvider)
      .getMonthlyReport(year, month);
}

/// A single visit for the detail page. Prefers a cached copy from today's
/// status or the current month's report (so navigating from a list doesn't
/// refetch), falling back to `GET /unplanned-visits/:id`.
@riverpod
Future<UnplannedVisit> unplannedVisitById(Ref ref, String id) async {
  final today = ref.read(unplannedVisitsTodayProvider).value;
  if (today != null) {
    for (final v in today.visits) {
      if (v.id == id) return v;
    }
  }
  final now = DateTime.now();
  final month = ref
      .read(unplannedVisitsMonthlyReportProvider(now.year, now.month))
      .value;
  if (month != null) {
    for (final v in month.records) {
      if (v.id == id) return v;
    }
  }
  return ref.watch(unplannedVisitRepositoryProvider).getById(id);
}
