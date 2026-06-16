import 'package:drift/drift.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/tables/tracking_pings_table.dart';

part 'tracking_pings_dao.g.dart';

/// The GPS ping outbox accessor. Driven entirely by the background isolate:
/// [enqueue] on every fix, [pending] on (re)connect to build a batch,
/// [deleteByClientIds] once the server acks. `insertOrIgnore` makes enqueue
/// idempotent on the unique [TrackingPings.clientPingId].
@DriftAccessor(tables: <Type>[TrackingPings])
class TrackingPingsDao extends DatabaseAccessor<AppDatabase>
    with _$TrackingPingsDaoMixin {
  TrackingPingsDao(super.db);

  Future<int> enqueue(TrackingPingsCompanion ping) {
    return into(trackingPings).insert(ping, mode: InsertMode.insertOrIgnore);
  }

  /// Oldest-first so a batch flush replays in chronological order. Capped to
  /// the server's per-batch ceiling by the caller (`TRACKING_BATCH_MAX`).
  Future<List<TrackingPingRow>> pending({int limit = 500}) {
    return (select(trackingPings)
          ..orderBy(<OrderingTerm Function(TrackingPings)>[
            (p) => OrderingTerm(expression: p.recordedAt),
          ])
          ..limit(limit))
        .get();
  }

  Future<List<TrackingPingRow>> pendingForBeatPlan(
    String beatPlanId, {
    int limit = 500,
  }) {
    return (select(trackingPings)
          ..where((p) => p.beatPlanId.equals(beatPlanId))
          ..orderBy(<OrderingTerm Function(TrackingPings)>[
            (p) => OrderingTerm(expression: p.recordedAt),
          ])
          ..limit(limit))
        .get();
  }

  Stream<int> watchPendingCount() {
    // Drift's TypedResult.read() keys on the exact Expression instance passed
    // to addColumns(), so the same `countExpr` must be reused for the read.
    final countExpr = trackingPings.id.count();
    return (selectOnly(trackingPings)..addColumns(<Expression<Object>>[countExpr]))
        .map((row) => row.read(countExpr) ?? 0)
        .watchSingle();
  }

  Future<int> countPending() async {
    final countExpr = trackingPings.id.count();
    final query = selectOnly(trackingPings)
      ..addColumns(<Expression<Object>>[countExpr]);
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  Future<void> deleteByClientIds(List<String> clientPingIds) async {
    if (clientPingIds.isEmpty) return;
    await (delete(trackingPings)
          ..where((p) => p.clientPingId.isIn(clientPingIds)))
        .go();
  }

  Future<void> deleteByClientId(String clientPingId) async {
    await (delete(trackingPings)
          ..where((p) => p.clientPingId.equals(clientPingId)))
        .go();
  }

  Future<int> clearForBeatPlan(String beatPlanId) {
    return (delete(trackingPings)..where((p) => p.beatPlanId.equals(beatPlanId)))
        .go();
  }

  Future<int> clearAll() => delete(trackingPings).go();
}
