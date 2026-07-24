import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/features/beat_plan/data/repositories/beat_plan_repository_impl.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/repositories/beat_plan_repository.dart';

part 'visit_stop_usecase.g.dart';

/// Marks a stop visited, attaching the rep's current GPS fix as the
/// check-in location (best-effort — the write still goes through if location
/// is unavailable). Earns its place over a raw repo call by owning the
/// location capture side effect.
class VisitStopUseCase {
  VisitStopUseCase(this._repo, this._location);

  final BeatPlanRepository _repo;
  final LocationService _location;

  Future<void> call({
    required String beatPlanId,
    required String stopId,
    DateTime? visitStartedAt,
    String? notes,
    DateTime? followUpDate,
    String? imagePath,
  }) async {
    final position = await _location.getCurrentLocation();
    await _repo.visitStop(
      beatPlanId: beatPlanId,
      stopId: stopId,
      latitude: position?.latitude,
      longitude: position?.longitude,
      visitStartedAt: visitStartedAt,
      visitEndedAt: DateTime.now(),
      notes: notes,
      followUpDate: followUpDate,
      imagePath: imagePath,
    );
  }
}

@riverpod
VisitStopUseCase visitStopUseCase(Ref ref) => VisitStopUseCase(
      ref.watch(beatPlanRepositoryProvider),
      ref.watch(locationServiceProvider),
    );
