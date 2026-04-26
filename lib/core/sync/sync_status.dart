enum SyncPhase { idle, syncing, error }

class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.pendingCount = 0,
    this.lastError,
    this.lastSyncedAt,
  });

  const SyncStatus.idle({int pending = 0, DateTime? lastSyncedAt})
      : this(
          phase: SyncPhase.idle,
          pendingCount: pending,
          lastSyncedAt: lastSyncedAt,
        );
  const SyncStatus.syncing({int pending = 0})
      : this(phase: SyncPhase.syncing, pendingCount: pending);
  const SyncStatus.error(String error, {int pending = 0})
      : this(
          phase: SyncPhase.error,
          pendingCount: pending,
          lastError: error,
        );

  final SyncPhase phase;
  final int pendingCount;
  final String? lastError;
  final DateTime? lastSyncedAt;
}
