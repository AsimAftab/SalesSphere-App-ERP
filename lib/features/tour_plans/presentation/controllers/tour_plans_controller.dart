import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/tour_plans/domain/tour_plan.dart';
// `tour_plans_providers.dart` re-exports `tourPlansRepositoryProvider`
// so the controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/tour_plans/presentation/providers/tour_plans_providers.dart';

part 'tour_plans_controller.g.dart';

/// Routes tour-plan write actions from the UI through the repository.
/// Reads stay on `tourPlansListProvider` and `tourPlanByIdProvider`.
///
/// Each write method opens a `ref.keepAlive()` link for the duration
/// of its in-flight `await` and closes it in `finally`. That keeps the
/// notifier (and its `ref`) valid through the post-await
/// `ref.invalidate(...)` without permanently pinning a write-only
/// controller in memory.
@riverpod
class TourPlansController extends _$TourPlansController {
  @override
  void build() {}

  Future<TourPlan> addTourPlan(TourPlan draft) async {
    final link = ref.keepAlive();
    try {
      final created = await ref
          .read(tourPlansRepositoryProvider)
          .addTourPlan(draft);
      ref.invalidate(tourPlansListProvider);
      return created;
    } finally {
      link.close();
    }
  }

  Future<TourPlan> updateTourPlan(TourPlan plan) async {
    final link = ref.keepAlive();
    try {
      final updated = await ref
          .read(tourPlansRepositoryProvider)
          .updateTourPlan(plan);
      ref.invalidate(tourPlansListProvider);
      return updated;
    } finally {
      link.close();
    }
  }
}
