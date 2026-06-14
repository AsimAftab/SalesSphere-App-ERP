import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan_stop.dart';

/// Domain-side contract for beat-plan data. The concrete implementation
/// (DTO ↔ domain mapping, drift persistence, outbox enqueue) lives in
/// `data/repositories/beat_plan_repository_impl.dart`.
///
/// Reads are drift-backed `Stream`s so the route list + detail stay live
/// (and work offline) as the cache is upserted. Writes are offline-first:
/// `visitStop` / `skipStop` try the network, then fall back to an optimistic
/// drift update + outbox enqueue when there's no connectivity.
abstract class BeatPlanRepository {
  /// Reactive list of cached plans, newest scheduled first.
  Stream<List<BeatPlan>> watchBeatPlans();

  /// Reactive single plan summary (no stops). Null until the plan is cached.
  Stream<BeatPlan?> watchBeatPlan(String id);

  /// Reactive ordered stops for a plan.
  Stream<List<BeatPlanStop>> watchStops(String beatPlanId);

  /// Fetch the plan list from the server and upsert into drift. Swallows
  /// nothing — the caller decides how to treat offline errors.
  Future<void> refreshBeatPlans();

  /// Fetch a single plan's detail (with stops) and upsert into drift.
  Future<void> refreshBeatPlan(String id);

  /// Transition the plan to ACTIVE (`POST /beat-plans/:id/start`). Requires
  /// connectivity — a tracking session can't be opened offline.
  Future<void> startPlan(String id);

  /// Mark a stop visited with timing/notes/follow-up + optional proof photo.
  /// Optimistic + offline-tolerant (the photo is dropped on the offline path).
  Future<void> visitStop({
    required String beatPlanId,
    required String stopId,
    double? latitude,
    double? longitude,
    DateTime? visitStartedAt,
    DateTime? visitEndedAt,
    String? notes,
    DateTime? followUpDate,
    String? imagePath,
  });

  /// Mark a stop skipped. Optimistic + offline-tolerant.
  Future<void> skipStop({
    required String beatPlanId,
    required String stopId,
    double? latitude,
    double? longitude,
  });
}
