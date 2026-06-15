import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/tracking/data/tracking_api.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_prefs.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_service.dart';

part 'reconcile_tracking_usecase.g.dart';

/// Cold-start / app-resume recovery for tracking. This — not boot auto-start —
/// is how a session survives a reboot or an OEM process kill: when the rep
/// reopens the app, we check whether a session that was active is still open
/// server-side and relaunch the foreground service if so.
class ReconcileTrackingUseCase {
  ReconcileTrackingUseCase(this._api);

  final TrackingApi _api;

  Future<void> call() async {
    final intent = await TrackingPrefs.read();
    if (intent == null || !intent.active) return;
    // Already running — nothing to recover.
    if (await isTrackingServiceRunning()) return;

    try {
      final status = await _api.activeSessionStatus(intent.beatPlanId);
      if (status == 'ACTIVE' || status == 'PAUSED') {
        await _relaunch(intent);
      } else {
        // Server says the session is gone (completed/force-stopped while we
        // were away). Drop the stale intent so we don't resume it.
        await TrackingPrefs.clear();
      }
    } on DioException {
      // Offline — can't verify. Resume locally so GPS keeps buffering; the
      // server reconciles (and force-stops if needed) once we reconnect.
      await _relaunch(intent);
    }
  }

  Future<void> _relaunch(TrackingIntent intent) => startTrackingService(
        beatPlanId: intent.beatPlanId,
        total: intent.total,
        visited: intent.visited,
        skipped: intent.skipped,
      );
}

@riverpod
ReconcileTrackingUseCase reconcileTrackingUseCase(Ref ref) =>
    ReconcileTrackingUseCase(ref.watch(trackingApiProvider));
