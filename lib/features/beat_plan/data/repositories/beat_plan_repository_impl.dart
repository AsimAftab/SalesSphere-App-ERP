import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/endpoints.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/daos/beat_plan_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/outbox_dao.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/core/utils/uuid.dart';
import 'package:sales_sphere_erp/features/beat_plan/data/beat_plan_api.dart';
import 'package:sales_sphere_erp/features/beat_plan/data/dto/beat_plan_dto.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan_stop.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/repositories/beat_plan_repository.dart';

/// Outbox operation keys. Must match the `operation` getters on the
/// registered [BeatPlanStopSyncHandler]s so the sync drain can reconcile
/// queued visit/skip writes.
const String kBeatPlanVisitOperation = 'beat_plan.visit';
const String kBeatPlanSkipOperation = 'beat_plan.skip';

/// Anti-corruption layer between the beat-plan wire DTOs and the rest of the
/// app. Drift is the read-side cache; every list/detail fetch is upserted and
/// the UI watches drift streams. `visitStop` / `skipStop` are offline-tolerant
/// in the parties mould: try the network, and on a connectivity failure flip
/// the stop optimistically + enqueue the write for the sync drain.
class BeatPlanRepositoryImpl implements BeatPlanRepository {
  BeatPlanRepositoryImpl({
    required BeatPlanApi api,
    required BeatPlanDao dao,
    required OutboxDao outbox,
  })  : _api = api,
        _dao = dao,
        _outbox = outbox;

  final BeatPlanApi _api;
  final BeatPlanDao _dao;
  final OutboxDao _outbox;

  // ── Reads ───────────────────────────────────────────────────────────────
  @override
  Stream<List<BeatPlan>> watchBeatPlans() {
    return _dao.watchAll().map(
          (rows) => rows.map(_rowToPlan).toList(growable: false),
        );
  }

  @override
  Stream<BeatPlan?> watchBeatPlan(String id) {
    return _dao.watchById(id).map((row) => row == null ? null : _rowToPlan(row));
  }

  @override
  Stream<List<BeatPlanStop>> watchStops(String beatPlanId) {
    return _dao.watchStops(beatPlanId).map(
          (rows) => rows.map(_rowToStop).toList(growable: false),
        );
  }

  @override
  Future<void> refreshBeatPlans() async {
    final page = await _api.list();
    // replaceAll (not upsert) so plans deleted/unassigned server-side are
    // pruned from the cache — otherwise a stale plan lingers forever.
    await _dao.replaceAll(
      page.items.map(_planCompanion).toList(growable: false),
    );
  }

  @override
  Future<void> refreshBeatPlan(String id) async {
    try {
      final dto = await _api.getById(id);
      await _dao.upsertPlanWithStops(
        _planCompanion(dto),
        dto.stops
            .map((s) => _stopCompanion(dto.id, s))
            .toList(growable: false),
      );
    } on DioException catch (e) {
      // Deleted server-side while cached — drop it locally too.
      if (e.response?.statusCode == 404) {
        await _dao.deletePlan(id);
        return;
      }
      rethrow;
    }
  }

  // ── Writes ──────────────────────────────────────────────────────────────
  @override
  Future<void> startPlan(String id) async {
    final dto = await _api.start(id);
    await _dao.upsertPlans(<BeatPlansCompanion>[_planCompanion(dto)]);
  }

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
    final endedAt = visitEndedAt ?? DateTime.now();
    final rawDuration = visitStartedAt == null
        ? null
        : endedAt.difference(visitStartedAt).inSeconds;
    final durationSec =
        rawDuration == null ? null : (rawDuration < 0 ? 0 : rawDuration);
    try {
      final updated = await _api.visit(
        beatPlanId: beatPlanId,
        stopId: stopId,
        latitude: latitude,
        longitude: longitude,
        visitStartedAt: visitStartedAt,
        visitEndedAt: endedAt,
        notes: notes,
        followUpDate: followUpDate,
      );
      // The visit returns the full plan (with server-computed duration) — upsert.
      await _dao.upsertPlanWithStops(
        _planCompanion(updated),
        updated.stops
            .map((s) => _stopCompanion(updated.id, s))
            .toList(growable: false),
      );
      // Best-effort proof-photo upload (separate endpoint); non-fatal.
      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          final url = await _api.uploadStopImage(
            beatPlanId: beatPlanId,
            stopId: stopId,
            filePath: imagePath,
          );
          if (url != null) await _dao.setStopImage(stopId, url);
        } on DioException {
          // Visit is recorded; the photo can be retried later. Ignore.
        }
      }
    } on DioException catch (e) {
      if (e.error is! OfflineException) rethrow;
      // Offline: optimistic local visit + queue the JSON. The photo is dropped
      // (binary outbox is future work, matching the parties pattern).
      // Atomic: the pending flag and the queued mutation must commit together,
      // else a crash between them orphans the stop as syncPending with no
      // outbox row to ever reconcile it.
      await _dao.attachedDatabase.transaction(() async {
        await _dao.markStopPending(
          stopId,
          status: 'VISITED',
          visitStartedAt: visitStartedAt,
          visitedAt: endedAt,
          visitDurationSec: durationSec,
          notes: notes,
          followUpDate: followUpDate,
          visitLatitude: latitude,
          visitLongitude: longitude,
        );
        await _outbox.enqueue(
          MutationOutboxCompanion.insert(
            operation: kBeatPlanVisitOperation,
            method: 'POST',
            endpoint: Endpoints.beatPlanVisit(beatPlanId),
            payloadJson: Value<String>(
              jsonEncode(
                BeatPlanApi.visitBody(
                  stopId: stopId,
                  latitude: latitude,
                  longitude: longitude,
                  visitStartedAt: visitStartedAt,
                  visitEndedAt: endedAt,
                  notes: notes,
                  followUpDate: followUpDate,
                ),
              ),
            ),
            idempotencyKey: generateUuidV4(),
            localEntityId: Value<String?>(stopId),
          ),
        );
      });
    }
  }

  @override
  Future<void> skipStop({
    required String beatPlanId,
    required String stopId,
    double? latitude,
    double? longitude,
  }) async {
    final at = DateTime.now();
    try {
      await _api.skip(
        beatPlanId: beatPlanId,
        stopId: stopId,
        latitude: latitude,
        longitude: longitude,
      );
      await _dao.markStopPending(
        stopId,
        status: 'SKIPPED',
        skippedAt: at,
        visitLatitude: latitude,
        visitLongitude: longitude,
      );
      await _dao.markStopSyncSucceeded(stopId);
      unawaited(refreshBeatPlan(beatPlanId).catchError((Object _) {}));
    } on DioException catch (e) {
      if (e.error is! OfflineException) rethrow;
      // Atomic: optimistic skip flag + queued mutation commit together (see
      // visitStop) so a crash between them can't orphan the stop.
      await _dao.attachedDatabase.transaction(() async {
        await _dao.markStopPending(
          stopId,
          status: 'SKIPPED',
          skippedAt: at,
          visitLatitude: latitude,
          visitLongitude: longitude,
        );
        await _outbox.enqueue(
          MutationOutboxCompanion.insert(
            operation: kBeatPlanSkipOperation,
            method: 'POST',
            endpoint: Endpoints.beatPlanSkip(beatPlanId),
            payloadJson: Value<String>(
              jsonEncode(
                BeatPlanApi.visitBody(
                  stopId: stopId,
                  latitude: latitude,
                  longitude: longitude,
                ),
              ),
            ),
            idempotencyKey: generateUuidV4(),
            localEntityId: Value<String?>(stopId),
          ),
        );
      });
    }
  }

  // ── Mappers ─────────────────────────────────────────────────────────────
  BeatPlansCompanion _planCompanion(BeatPlanDto dto) {
    return BeatPlansCompanion(
      id: Value<String>(dto.id),
      name: Value<String>(dto.name),
      status: Value<String>(dto.status),
      frequency: Value<String>(dto.frequency),
      scheduledDate: Value<DateTime>(dto.scheduledDate),
      endDate: Value<DateTime?>(dto.endDate),
      startedAt: Value<DateTime?>(dto.startedAt),
      completedAt: Value<DateTime?>(dto.completedAt),
      totalStops: Value<int>(dto.totalStops),
      visitedStops: Value<int>(dto.visitedStops),
      skippedStops: Value<int>(dto.skippedStops),
      syncPending: const Value<bool>(false),
      syncError: const Value<String?>(null),
    );
  }

  BeatPlanStopsCompanion _stopCompanion(String beatPlanId, BeatPlanStopDto s) {
    return BeatPlanStopsCompanion(
      id: Value<String>(s.id),
      beatPlanId: Value<String>(beatPlanId),
      kind: Value<String>(s.kind),
      entityId: Value<String?>(s.entityId),
      name: Value<String?>(s.name),
      address: Value<String?>(s.address),
      latitude: Value<double?>(s.latitude),
      longitude: Value<double?>(s.longitude),
      sortOrder: Value<int>(s.sortOrder),
      status: Value<String>(s.status),
      visitStartedAt: Value<DateTime?>(s.visitStartedAt),
      visitedAt: Value<DateTime?>(s.visitedAt),
      visitDurationSec: Value<int?>(s.visitDurationSec),
      skippedAt: Value<DateTime?>(s.skippedAt),
      visitNotes: Value<String?>(s.visitNotes),
      followUpDate: Value<DateTime?>(s.followUpDate),
      visitImageUrl: Value<String?>(s.visitImageUrl),
      visitLatitude: Value<double?>(s.visitLatitude),
      visitLongitude: Value<double?>(s.visitLongitude),
      distanceToNextKm: Value<double?>(s.distanceToNextKm),
      syncPending: const Value<bool>(false),
      syncError: const Value<String?>(null),
    );
  }

  BeatPlan _rowToPlan(BeatPlanRow r) {
    final total = r.totalStops;
    final visited = r.visitedStops;
    final skipped = r.skippedStops;
    final pending = (total - visited - skipped).clamp(0, total);
    final progress =
        total == 0 ? 0.0 : ((visited + skipped) / total).clamp(0.0, 1.0);
    return BeatPlan(
      id: r.id,
      title: r.name,
      status: _titleCase(r.status),
      frequency: r.frequency,
      assignedDate: r.scheduledDate,
      startedDate: r.startedAt ?? r.scheduledDate,
      completedAt: r.completedAt,
      progress: progress.toDouble(),
      total: total,
      visited: visited,
      pending: pending,
      skipped: skipped,
      syncPending: r.syncPending,
      syncError: r.syncError,
    );
  }

  BeatPlanStop _rowToStop(BeatPlanStopRow r) {
    return BeatPlanStop(
      id: r.id,
      beatPlanId: r.beatPlanId,
      kind: r.kind,
      status: r.status,
      entityId: r.entityId,
      name: r.name,
      address: r.address,
      latitude: r.latitude,
      longitude: r.longitude,
      sortOrder: r.sortOrder,
      visitStartedAt: r.visitStartedAt,
      visitedAt: r.visitedAt,
      visitDurationSec: r.visitDurationSec,
      skippedAt: r.skippedAt,
      visitNotes: r.visitNotes,
      followUpDate: r.followUpDate,
      visitImageUrl: r.visitImageUrl,
      distanceToNextKm: r.distanceToNextKm,
      syncPending: r.syncPending,
      syncError: r.syncError,
    );
  }

  String _titleCase(String raw) {
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }
}

/// Exposes the abstract type so consumers depend on the contract, not the
/// impl. Tests override this with a fake `BeatPlanRepository`.
final beatPlanRepositoryProvider = Provider<BeatPlanRepository>((ref) {
  return BeatPlanRepositoryImpl(
    api: ref.watch(beatPlanApiProvider),
    dao: ref.watch(beatPlanDaoProvider),
    outbox: ref.watch(outboxDaoProvider),
  );
});
