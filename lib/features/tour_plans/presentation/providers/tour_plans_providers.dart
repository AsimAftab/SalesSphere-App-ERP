import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/tour_plans/data/repositories/tour_plans_repository_impl.dart';
import 'package:sales_sphere_erp/features/tour_plans/domain/tour_plan.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`. The impl import above stays because this
// file actually uses the provider in its own watch calls.
export 'package:sales_sphere_erp/features/tour_plans/data/repositories/tour_plans_repository_impl.dart'
    show tourPlansRepositoryProvider;

part 'tour_plans_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<TourPlan>> tourPlansList(Ref ref) async {
  return ref.watch(tourPlansRepositoryProvider).getTourPlans();
}

/// Resolves a single tour plan by id. Derived from the list provider's
/// `AsyncValue` so loading and error states propagate to consumers
/// instead of collapsing into `null`.
@riverpod
Future<TourPlan?> tourPlanById(Ref ref, String id) async {
  final plans = await ref.watch(tourPlansListProvider.future);
  for (final plan in plans) {
    if (plan.id == id) return plan;
  }
  return null;
}
