import 'package:sales_sphere_erp/features/tour_plans/domain/tour_plan.dart';

/// Domain-side contract for tour-plans data. The concrete implementation
/// (DTO mapping, drift persistence, outbox enqueue) lives in
/// `data/repositories/tour_plans_repository_impl.dart`.
abstract class TourPlansRepository {
  Future<List<TourPlan>> getTourPlans({TourPlanStatus? status, int limit = 10});

  Future<TourPlan?> getTourPlanById(String id);

  Future<TourPlan> addTourPlan(TourPlan draft);

  Future<TourPlan> updateTourPlan(TourPlan plan);

  Future<TourPlan> markTourPlanCompleted(String id);
}
