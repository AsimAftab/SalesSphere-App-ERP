import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/beat_plan/data/repositories/beat_plan_repository_impl.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/repositories/beat_plan_repository.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_permissions.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_service.dart';

part 'start_tracking_usecase.g.dart';

enum StartTrackingOutcome { started, permissionDenied, error }

class StartTrackingResult {
  const StartTrackingResult(this.outcome, {this.message, this.warning});

  final StartTrackingOutcome outcome;

  /// User-facing reason for a denied/error outcome.
  final String? message;

  /// Non-blocking caveat when tracking started but isn't fully kill-resilient
  /// (e.g. background-location not granted).
  final String? warning;

  bool get started => outcome == StartTrackingOutcome.started;
}

/// Composes the full "start tracking" action: permission gauntlet → REST
/// `start` (plan → ACTIVE) → launch the foreground service (which opens the
/// socket session + begins GPS). Genuinely multi-step with side effects, so it
/// earns its place as a use case.
class StartTrackingUseCase {
  StartTrackingUseCase(this._repo, this._permissions);

  final BeatPlanRepository _repo;
  final TrackingPermissions _permissions;

  Future<StartTrackingResult> call(BeatPlan plan) async {
    final permission = await _permissions.ensureForTracking();
    if (!permission.granted) {
      return StartTrackingResult(
        StartTrackingOutcome.permissionDenied,
        message: permission.message,
      );
    }

    try {
      await _repo.startPlan(plan.id);
    } on DioException catch (e) {
      return StartTrackingResult(
        StartTrackingOutcome.error,
        message: extractBackendErrorMessage(e) ??
            'Could not start the beat plan. Check your connection and try again.',
      );
    }

    await startTrackingService(
      beatPlanId: plan.id,
      total: plan.total,
      visited: plan.visited,
      skipped: plan.skipped,
    );

    return StartTrackingResult(
      StartTrackingOutcome.started,
      warning: permission.backgroundGranted ? null : permission.message,
    );
  }
}

@riverpod
StartTrackingUseCase startTrackingUseCase(Ref ref) => StartTrackingUseCase(
      ref.watch(beatPlanRepositoryProvider),
      ref.watch(trackingPermissionsProvider),
    );
