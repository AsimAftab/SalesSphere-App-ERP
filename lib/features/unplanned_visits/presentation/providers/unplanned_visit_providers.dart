import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/unplanned_visits/data/repositories/unplanned_visit_repository_impl.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
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

/// A single visit for the detail page. Prefers a cached copy from today's
/// status (so navigating from the list doesn't refetch), falling back to
/// `GET /unplanned-visits/:id`.
@riverpod
Future<UnplannedVisit> unplannedVisitById(Ref ref, String id) async {
  final today = ref.read(unplannedVisitsTodayProvider).value;
  if (today != null) {
    for (final v in today.visits) {
      if (v.id == id) return v;
    }
  }
  return ref.watch(unplannedVisitRepositoryProvider).getById(id);
}
