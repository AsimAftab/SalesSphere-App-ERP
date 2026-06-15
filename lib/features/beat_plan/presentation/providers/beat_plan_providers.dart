import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/beat_plan/data/repositories/beat_plan_repository_impl.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan_stop.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/usecases/skip_stop_usecase.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/usecases/visit_stop_usecase.dart';

part 'beat_plan_providers.g.dart';

@Riverpod(keepAlive: true)
class BeatPlanTabIndex extends _$BeatPlanTabIndex {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

/// The "My Beat Plans" list. Backed by the drift cache so it renders offline
/// and stays live as the cache is upserted (network refresh) or mutated
/// (optimistic visit/skip). `build()` also kicks a background refresh.
@Riverpod(keepAlive: true)
class BeatPlanController extends _$BeatPlanController {
  StreamSubscription<List<BeatPlan>>? _sub;

  @override
  Future<List<BeatPlan>> build() async {
    final repo = ref.watch(beatPlanRepositoryProvider);
    final stream = repo.watchBeatPlans();

    _sub = stream.listen((plans) => state = AsyncData<List<BeatPlan>>(plans));
    ref.onDispose(() => _sub?.cancel());

    // Best-effort network refresh; offline falls back to the cache below.
    unawaited(_refresh());

    return stream.first;
  }

  Future<void> _refresh() async {
    try {
      await ref.read(beatPlanRepositoryProvider).refreshBeatPlans();
    } on Object {
      // Offline / transient — drift remains the source of truth.
    }
  }

  Future<void> refresh() => _refresh();

  /// Transition the plan to ACTIVE. Tracking itself is started by the
  /// `TrackingController` (see tracking feature).
  Future<void> startPlan(String id) async {
    await ref.read(beatPlanRepositoryProvider).startPlan(id);
    unawaited(_refresh());
  }

  Future<void> visitStop({
    required String beatPlanId,
    required String stopId,
    DateTime? visitStartedAt,
    String? notes,
    DateTime? followUpDate,
    String? imagePath,
  }) {
    return ref.read(visitStopUseCaseProvider).call(
          beatPlanId: beatPlanId,
          stopId: stopId,
          visitStartedAt: visitStartedAt,
          notes: notes,
          followUpDate: followUpDate,
          imagePath: imagePath,
        );
  }

  Future<void> skipStop({
    required String beatPlanId,
    required String stopId,
  }) {
    return ref.read(skipStopUseCaseProvider).call(
          beatPlanId: beatPlanId,
          stopId: stopId,
        );
  }
}

/// Reactive single-plan summary (counters/status, no stops). Kicks a detail
/// refresh so deep-linked / cold-started plans hydrate their stops too.
@riverpod
Stream<BeatPlan?> beatPlanById(Ref ref, String id) {
  final repo = ref.watch(beatPlanRepositoryProvider);
  unawaited(repo.refreshBeatPlan(id).catchError((Object _) {}));
  return repo.watchBeatPlan(id);
}

/// Reactive ordered stops for a plan's detail page.
@riverpod
Stream<List<BeatPlanStop>> beatPlanStops(Ref ref, String beatPlanId) {
  return ref.watch(beatPlanRepositoryProvider).watchStops(beatPlanId);
}
