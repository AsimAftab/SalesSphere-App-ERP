import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/sync/sync_service.dart';
import 'package:sales_sphere_erp/core/sync/sync_status.dart';
import 'package:sales_sphere_erp/core/utils/app_logger_provider.dart';

const Duration _syncTickInterval = Duration(seconds: 30);

class SyncScheduler extends Notifier<SyncStatus> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Stream<int>? _pendingStream;
  StreamSubscription<int>? _pendingSub;
  Timer? _ticker;
  bool _wasOffline = false;

  @override
  SyncStatus build() {
    final connectivity = ref.watch(connectivityProvider);
    final outbox = ref.watch(outboxDaoProvider);

    _pendingStream = outbox.watchPendingCount();
    _pendingSub = _pendingStream!.listen((count) {
      if (state.pendingCount != count) {
        state = SyncStatus(
          phase: state.phase,
          pendingCount: count,
          lastError: state.lastError,
          lastSyncedAt: state.lastSyncedAt,
        );
      }
    });

    _connectivitySub = connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    _ticker = Timer.periodic(_syncTickInterval, (_) {
      unawaited(syncNow());
    });

    ref.onDispose(() {
      _connectivitySub?.cancel();
      _pendingSub?.cancel();
      _ticker?.cancel();
    });

    return const SyncStatus.idle();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    final logger = ref.read(appLoggerProvider);

    if (!hasNetwork) {
      _wasOffline = true;
      logger.info('Connectivity lost — sync paused');
      return;
    }

    if (_wasOffline) {
      _wasOffline = false;
      logger.info('Connectivity restored — draining outbox');
      unawaited(syncNow());
    }
  }

  /// Manually triggered sync — also called periodically and on connectivity
  /// restore. No-ops if a drain is already running.
  Future<void> syncNow() async {
    if (state.phase == SyncPhase.syncing) return;
    state = SyncStatus.syncing(pending: state.pendingCount);
    final result = await ref.read(syncServiceProvider).drain();
    state = result;
  }
}

final syncSchedulerProvider =
    NotifierProvider<SyncScheduler, SyncStatus>(SyncScheduler.new);
