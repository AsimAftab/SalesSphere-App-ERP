import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/features/beat_plan/data/repositories/beat_plan_repository_impl.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/repositories/beat_plan_repository.dart';

part 'skip_stop_usecase.g.dart';

/// Marks a stop skipped, attaching the rep's current GPS fix (best-effort).
/// Finishing the last pending stop completes the plan server-side and closes
/// tracking (`tracking-force-stopped` / `beat_plan_completed`).
class SkipStopUseCase {
  SkipStopUseCase(this._repo, this._location);

  final BeatPlanRepository _repo;
  final LocationService _location;

  Future<void> call({
    required String beatPlanId,
    required String stopId,
  }) async {
    final position = await _location.getCurrentLocation();
    await _repo.skipStop(
      beatPlanId: beatPlanId,
      stopId: stopId,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
  }
}

@riverpod
SkipStopUseCase skipStopUseCase(Ref ref) => SkipStopUseCase(
      ref.watch(beatPlanRepositoryProvider),
      ref.watch(locationServiceProvider),
    );
