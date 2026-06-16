import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/features/beat_plan/data/repositories/beat_plan_repository_impl.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan.dart';
import 'package:sales_sphere_erp/features/tracking/domain/tracking_live_state.dart';
import 'package:sales_sphere_erp/features/tracking/domain/usecases/start_tracking_usecase.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_ipc.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_service.dart';

part 'tracking_controller.g.dart';

/// One-shot "session ended" notice (force-stop reason / stop). The UI
/// `ref.listen`s this, shows a snackbar, then clears it.
@riverpod
class TrackingNotice extends _$TrackingNotice {
  @override
  String? build() => null;

  void show(String? message) => state = message;

  void clear() => state = null;
}

/// Bridges the background tracking service to the UI: subscribes to the live
/// state + lifecycle events the service pushes, persists completed-session
/// summaries (UI isolate is the sole writer of `tracking_summaries`), and
/// relays start/pause/resume/stop commands. Kept alive for the app lifetime
/// (watched in `app.dart`) so it catches a force-stop even between screens.
@Riverpod(keepAlive: true)
class TrackingController extends _$TrackingController {
  final List<StreamSubscription<Map<String, dynamic>?>> _subs =
      <StreamSubscription<Map<String, dynamic>?>>[];

  @override
  TrackingLiveState build() {
    final service = FlutterBackgroundService();
    _subs
      ..add(service.on(TrackingIpc.evtState).listen(_onState))
      ..add(service
          .on(TrackingIpc.evtForceStopped)
          .listen((a) => unawaited(_onEnded(a))))
      ..add(service
          .on(TrackingIpc.evtStopped)
          .listen((a) => unawaited(_onEnded(a))));

    ref.onDispose(() {
      for (final sub in _subs) {
        unawaited(sub.cancel());
      }
    });

    // If a session is already running (e.g. UI restarted), pull its state now.
    unawaited(service.isRunning().then((running) {
      if (running) service.invoke(TrackingIpc.cmdSync);
    }));

    return const TrackingLiveState.idle();
  }

  void _onState(Map<String, dynamic>? args) {
    if (args == null) return;
    state = TrackingLiveState.fromMap(args);
  }

  Future<void> _onEnded(Map<String, dynamic>? args) async {
    if (args == null) return;
    final beatPlanId = args[TrackingIpc.kBeatPlanId] as String?;
    final sessionId = args[TrackingIpc.kSessionId] as String?;

    // Persist the summary locally for the history view (server is still
    // authoritative; cold-start reconcile fills gaps if we missed this).
    if (beatPlanId != null &&
        sessionId != null &&
        args.containsKey('totalDistanceKm')) {
      await ref.read(trackingDaoProvider).upsertSummary(
            TrackingSummariesCompanion.insert(
              sessionId: sessionId,
              beatPlanId: beatPlanId,
              totalDistanceKm: Value<double>(
                (args['totalDistanceKm'] as num?)?.toDouble() ?? 0,
              ),
              totalDurationMin: Value<int>(
                (args['totalDurationMin'] as num?)?.toInt() ?? 0,
              ),
              averageSpeedKmh: Value<double>(
                (args['averageSpeedKmh'] as num?)?.toDouble() ?? 0,
              ),
              directoriesVisited: Value<int>(
                (args['directoriesVisited'] as num?)?.toInt() ?? 0,
              ),
              reason: Value<String?>(args[TrackingIpc.kReason] as String?),
            ),
          );
    }

    // Refresh the plan so its status flips to completed in the UI.
    if (beatPlanId != null) {
      unawaited(
        ref
            .read(beatPlanRepositoryProvider)
            .refreshBeatPlan(beatPlanId)
            .catchError((Object _) {}),
      );
    }

    final label = args[TrackingIpc.kReasonLabel] as String?;
    if (label != null) {
      ref.read(trackingNoticeProvider.notifier).show(label);
    }

    state = const TrackingLiveState.idle();
  }

  /// Permission gauntlet → REST start → launch the foreground service. This is
  /// the single deliberate "start" action; an active plan auto-resumes silently
  /// (see `ensureTrackingRunning`), so there's no user-facing resume.
  Future<StartTrackingResult> startForPlan(BeatPlan plan) {
    return ref.read(startTrackingUseCaseProvider).call(plan);
  }
}
