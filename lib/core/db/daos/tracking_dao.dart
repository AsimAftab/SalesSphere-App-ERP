import 'package:drift/drift.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/tables/tracking_sessions_table.dart';
import 'package:sales_sphere_erp/core/db/tables/tracking_summaries_table.dart';

part 'tracking_dao.g.dart';

/// Session + summary access. [TrackingSessions] is written by the background
/// isolate (live runtime); [TrackingSummaries] by the UI isolate (history).
/// Both isolates open their own [AppDatabase] over the same file, so these
/// methods avoid cross-table writes that would break the single-writer rule.
@DriftAccessor(tables: <Type>[TrackingSessions, TrackingSummaries])
class TrackingDao extends DatabaseAccessor<AppDatabase>
    with _$TrackingDaoMixin {
  TrackingDao(super.db);

  // ── Sessions (bg isolate writer) ──────────────────────────────────────────
  Future<TrackingSessionRow?> activeForBeatPlan(String beatPlanId) {
    return (select(trackingSessions)
          ..where((s) =>
              s.beatPlanId.equals(beatPlanId) &
              s.status.isNotValue('COMPLETED'))
          ..orderBy(<OrderingTerm Function(TrackingSessions)>[
            (s) => OrderingTerm(
                  expression: s.startedAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<TrackingSessionRow?> watchActiveForBeatPlan(String beatPlanId) {
    return (select(trackingSessions)
          ..where((s) =>
              s.beatPlanId.equals(beatPlanId) &
              s.status.isNotValue('COMPLETED'))
          ..orderBy(<OrderingTerm Function(TrackingSessions)>[
            (s) => OrderingTerm(
                  expression: s.startedAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Any session not yet completed — the cold-start reconciler's starting
  /// point for "is there a route we should resume?".
  Future<List<TrackingSessionRow>> openSessions() {
    return (select(trackingSessions)
          ..where((s) => s.status.isNotValue('COMPLETED')))
        .get();
  }

  Future<void> upsertSession(TrackingSessionsCompanion session) {
    return into(trackingSessions).insertOnConflictUpdate(session);
  }

  /// Reconcile a provisional `local_<uuid>` session id to the server-issued
  /// one once `start-tracking` acks.
  Future<void> renameSession(String fromId, String toId) async {
    if (fromId == toId) return;
    await transaction(() async {
      final row = await (select(trackingSessions)
            ..where((s) => s.id.equals(fromId)))
          .getSingleOrNull();
      if (row == null) return;
      await (delete(trackingSessions)..where((s) => s.id.equals(fromId))).go();
      await into(trackingSessions).insertOnConflictUpdate(
        row.toCompanion(true).copyWith(id: Value<String>(toId)),
      );
    });
  }

  Future<void> updateLocation(
    String sessionId, {
    required double latitude,
    required double longitude,
    required DateTime recordedAt,
    double? totalDistanceKm,
  }) async {
    await (update(trackingSessions)..where((s) => s.id.equals(sessionId)))
        .write(
      TrackingSessionsCompanion(
        currentLatitude: Value<double?>(latitude),
        currentLongitude: Value<double?>(longitude),
        lastPingAt: Value<DateTime?>(recordedAt),
        totalDistanceKm: totalDistanceKm == null
            ? const Value<double>.absent()
            : Value<double>(totalDistanceKm),
      ),
    );
  }

  Future<void> setStatus(String sessionId, String status) async {
    await (update(trackingSessions)..where((s) => s.id.equals(sessionId)))
        .write(TrackingSessionsCompanion(status: Value<String>(status)));
  }

  Future<void> markCompleted(String sessionId, DateTime endedAt) async {
    await (update(trackingSessions)..where((s) => s.id.equals(sessionId)))
        .write(
      TrackingSessionsCompanion(
        status: const Value<String>('COMPLETED'),
        endedAt: Value<DateTime?>(endedAt),
      ),
    );
  }

  Future<void> deleteSession(String sessionId) async {
    await (delete(trackingSessions)..where((s) => s.id.equals(sessionId)))
        .go();
  }

  // ── Summaries (UI isolate writer) ─────────────────────────────────────────
  Future<void> upsertSummary(TrackingSummariesCompanion summary) {
    return into(trackingSummaries).insertOnConflictUpdate(summary);
  }

  Stream<TrackingSummaryRow?> watchSummary(String beatPlanId) {
    return (select(trackingSummaries)
          ..where((s) => s.beatPlanId.equals(beatPlanId))
          ..orderBy(<OrderingTerm Function(TrackingSummaries)>[
            (s) => OrderingTerm(
                  expression: s.completedAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }
}
