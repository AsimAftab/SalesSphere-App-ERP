import 'package:drift/drift.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/tables/beat_plan_stops_table.dart';
import 'package:sales_sphere_erp/core/db/tables/beat_plans_table.dart';

part 'beat_plan_dao.g.dart';

/// Read/write access for the beat-plan cache. Companion-based on purpose:
/// `core/db` stays free of feature-DTO imports, so the repository (which owns
/// DTO ↔ companion mapping) is the only translation point. Reads are exposed
/// as drift `Stream`s the UI watches; writes upsert server truth and support
/// the optimistic visit/skip path.
@DriftAccessor(tables: <Type>[BeatPlans, BeatPlanStops])
class BeatPlanDao extends DatabaseAccessor<AppDatabase>
    with _$BeatPlanDaoMixin {
  BeatPlanDao(super.db);

  // ── Reads (reactive) ──────────────────────────────────────────────────────
  Stream<List<BeatPlanRow>> watchAll() {
    return (select(beatPlans)
          ..orderBy(<OrderingTerm Function(BeatPlans)>[
            (p) => OrderingTerm(
                  expression: p.scheduledDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  Stream<BeatPlanRow?> watchById(String id) {
    return (select(beatPlans)..where((p) => p.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<BeatPlanRow?> findById(String id) {
    return (select(beatPlans)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<List<BeatPlanStopRow>> watchStops(String beatPlanId) {
    return (select(beatPlanStops)
          ..where((s) => s.beatPlanId.equals(beatPlanId))
          ..orderBy(<OrderingTerm Function(BeatPlanStops)>[
            (s) => OrderingTerm(expression: s.sortOrder),
          ]))
        .watch();
  }

  Future<List<BeatPlanStopRow>> stopsFor(String beatPlanId) {
    return (select(beatPlanStops)
          ..where((s) => s.beatPlanId.equals(beatPlanId))
          ..orderBy(<OrderingTerm Function(BeatPlanStops)>[
            (s) => OrderingTerm(expression: s.sortOrder),
          ]))
        .get();
  }

  Future<BeatPlanStopRow?> findStop(String stopId) {
    return (select(beatPlanStops)..where((s) => s.id.equals(stopId)))
        .getSingleOrNull();
  }

  // ── Writes ────────────────────────────────────────────────────────────────
  Future<void> upsertPlans(List<BeatPlansCompanion> plans) async {
    if (plans.isEmpty) return;
    await batch((b) {
      for (final p in plans) {
        b.insert(beatPlans, p, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// Reconcile the cache against the authoritative server list: upsert every
  /// returned plan AND prune any cached plan (+ its stops) the server no longer
  /// returns — so a plan deleted/unassigned server-side disappears on refresh.
  /// `syncPending` rows are preserved (they hold un-synced local writes).
  Future<void> replaceAll(List<BeatPlansCompanion> plans) async {
    final keepIds = plans.map((p) => p.id.value).toList(growable: false);
    await transaction(() async {
      final stale = select(beatPlans)
        ..where((p) {
          final notPending = p.syncPending.equals(false);
          return keepIds.isEmpty
              ? notPending
              : notPending & p.id.isNotIn(keepIds);
        });
      final staleIds = await stale.map((r) => r.id).get();
      if (staleIds.isNotEmpty) {
        await (delete(beatPlanStops)
              ..where((s) => s.beatPlanId.isIn(staleIds)))
            .go();
        await (delete(beatPlans)..where((p) => p.id.isIn(staleIds))).go();
      }
      for (final p in plans) {
        await into(beatPlans).insertOnConflictUpdate(p);
      }
    });
  }

  /// Drop a single plan and its stops — used when the server 404s a plan we
  /// still have cached (deleted while we were away).
  Future<void> deletePlan(String id) async {
    await transaction(() async {
      await (delete(beatPlanStops)..where((s) => s.beatPlanId.equals(id))).go();
      await (delete(beatPlans)..where((p) => p.id.equals(id))).go();
    });
  }

  /// Upsert a plan plus its full stop list. The server is authoritative on the
  /// route, so server stops replace cached ones — except rows currently
  /// flagged `syncPending`, whose optimistic local state wins until their
  /// outbox mutation reconciles.
  Future<void> upsertPlanWithStops(
    BeatPlansCompanion plan,
    List<BeatPlanStopsCompanion> stops,
  ) async {
    final planId = plan.id.value;
    await transaction(() async {
      await into(beatPlans).insertOnConflictUpdate(plan);
      final pendingIds = (await (select(beatPlanStops)
                ..where((s) =>
                    s.beatPlanId.equals(planId) & s.syncPending.equals(true)))
              .map((r) => r.id)
              .get())
          .toSet();
      await (delete(beatPlanStops)
            ..where((s) =>
                s.beatPlanId.equals(planId) & s.syncPending.equals(false)))
          .go();
      await batch((b) {
        for (final s in stops) {
          if (pendingIds.contains(s.id.value)) continue;
          b.insert(beatPlanStops, s, mode: InsertMode.insertOrReplace);
        }
      });
    });
  }

  /// Optimistically flip a stop's status while its visit/skip mutation is
  /// queued in the outbox. The card surfaces a pending badge off `syncPending`.
  /// Visit metadata (start time, duration, notes, follow-up) is stored so the
  /// card renders immediately; the server's values overwrite on the next
  /// refresh.
  Future<void> markStopPending(
    String stopId, {
    required String status,
    DateTime? visitStartedAt,
    DateTime? visitedAt,
    int? visitDurationSec,
    DateTime? skippedAt,
    String? notes,
    DateTime? followUpDate,
    double? visitLatitude,
    double? visitLongitude,
  }) async {
    await (update(beatPlanStops)..where((s) => s.id.equals(stopId))).write(
      BeatPlanStopsCompanion(
        status: Value<String>(status),
        visitStartedAt: Value<DateTime?>(visitStartedAt),
        visitedAt: Value<DateTime?>(visitedAt),
        visitDurationSec: Value<int?>(visitDurationSec),
        skippedAt: Value<DateTime?>(skippedAt),
        visitNotes: Value<String?>(notes),
        followUpDate: Value<DateTime?>(followUpDate),
        visitLatitude: Value<double?>(visitLatitude),
        visitLongitude: Value<double?>(visitLongitude),
        syncPending: const Value<bool>(true),
        syncError: const Value<String?>(null),
      ),
    );
    await recomputeCounters(await _beatPlanIdForStop(stopId));
  }

  /// Store the visit-proof photo URL on a stop (after a best-effort upload).
  Future<void> setStopImage(String stopId, String? url) async {
    await (update(beatPlanStops)..where((s) => s.id.equals(stopId)))
        .write(BeatPlanStopsCompanion(visitImageUrl: Value<String?>(url)));
  }

  Future<void> markStopSyncSucceeded(String stopId) async {
    await (update(beatPlanStops)..where((s) => s.id.equals(stopId))).write(
      const BeatPlanStopsCompanion(
        syncPending: Value<bool>(false),
        syncError: Value<String?>(null),
      ),
    );
  }

  Future<void> markStopSyncFailed(String stopId, String error) async {
    await (update(beatPlanStops)..where((s) => s.id.equals(stopId))).write(
      BeatPlanStopsCompanion(
        syncPending: const Value<bool>(true),
        syncError: Value<String?>(error),
      ),
    );
  }

  /// Recompute denormalised counters from the stop rows — keeps the progress
  /// card honest after an optimistic visit/skip, before the server confirms.
  Future<void> recomputeCounters(String beatPlanId) async {
    if (beatPlanId.isEmpty) return;
    final stops = await stopsFor(beatPlanId);
    final visited = stops.where((s) => s.status == 'VISITED').length;
    final skipped = stops.where((s) => s.status == 'SKIPPED').length;
    await (update(beatPlans)..where((p) => p.id.equals(beatPlanId))).write(
      BeatPlansCompanion(
        totalStops: Value<int>(stops.length),
        visitedStops: Value<int>(visited),
        skippedStops: Value<int>(skipped),
      ),
    );
  }

  Future<String> _beatPlanIdForStop(String stopId) async {
    final row = await findStop(stopId);
    return row?.beatPlanId ?? '';
  }

  Future<int> deleteAll() async {
    await delete(beatPlanStops).go();
    return delete(beatPlans).go();
  }
}
