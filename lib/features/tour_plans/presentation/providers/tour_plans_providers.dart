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
Future<List<TourPlan>> tourPlansList(Ref ref, {TourPlanStatus? status}) async {
  return ref.watch(tourPlansRepositoryProvider).getTourPlans(status: status);
}

/// Resolves a single tour plan by id from `GET /tour-plans/{id}`.
@riverpod
Future<TourPlan?> tourPlanById(Ref ref, String id) async {
  return ref.watch(tourPlansRepositoryProvider).getTourPlanById(id);
}
