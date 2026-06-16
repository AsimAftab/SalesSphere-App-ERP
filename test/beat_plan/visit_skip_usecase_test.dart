import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan_stop.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/repositories/beat_plan_repository.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/usecases/skip_stop_usecase.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/usecases/visit_stop_usecase.dart';

/// Captures the last visit/skip call so we can assert the use case forwards
/// to the repository. Only the two write methods are exercised.
class _FakeRepo implements BeatPlanRepository {
  String? visitedPlan;
  String? visitedStop;
  String? skippedPlan;
  String? skippedStop;

  @override
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
  }) async {
    visitedPlan = beatPlanId;
    visitedStop = stopId;
  }

  @override
  Future<void> skipStop({
    required String beatPlanId,
    required String stopId,
    double? latitude,
    double? longitude,
  }) async {
    skippedPlan = beatPlanId;
    skippedStop = stopId;
  }

  @override
  Stream<List<BeatPlan>> watchBeatPlans() => throw UnimplementedError();
  @override
  Stream<BeatPlan?> watchBeatPlan(String id) => throw UnimplementedError();
  @override
  Stream<List<BeatPlanStop>> watchStops(String beatPlanId) =>
      throw UnimplementedError();
  @override
  Future<void> refreshBeatPlans() => throw UnimplementedError();
  @override
  Future<void> refreshBeatPlan(String id) => throw UnimplementedError();
  @override
  Future<void> startPlan(String id) => throw UnimplementedError();
}

/// Location is unavailable in the test environment — returns null so the use
/// case proceeds with no GPS check-in (still a valid write).
class _FakeLocation extends LocationService {
  const _FakeLocation();
  @override
  Future<Position?> getCurrentLocation() async => null;
}

void main() {
  test('VisitStopUseCase forwards to the repository', () async {
    final repo = _FakeRepo();
    final useCase = VisitStopUseCase(repo, const _FakeLocation());

    await useCase.call(beatPlanId: 'bp1', stopId: 's1');

    expect(repo.visitedPlan, 'bp1');
    expect(repo.visitedStop, 's1');
  });

  test('SkipStopUseCase forwards to the repository', () async {
    final repo = _FakeRepo();
    final useCase = SkipStopUseCase(repo, const _FakeLocation());

    await useCase.call(beatPlanId: 'bp1', stopId: 's2');

    expect(repo.skippedPlan, 'bp1');
    expect(repo.skippedStop, 's2');
  });
}
