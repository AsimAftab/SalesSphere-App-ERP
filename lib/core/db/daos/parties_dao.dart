import 'package:drift/drift.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/tables/parties_table.dart';
import 'package:sales_sphere_erp/features/parties/data/dto/party_dto.dart';

part 'parties_dao.g.dart';

@DriftAccessor(tables: <Type>[Parties])
class PartiesDao extends DatabaseAccessor<AppDatabase>
    with _$PartiesDaoMixin {
  PartiesDao(super.db);

  /// Watch a list of party IDs, preserving caller-supplied order.
  /// `WHERE id IN (...)` returns rows in arbitrary order; we re-key by
  /// id in Dart so the rendered list stays stable across rebuilds.
  Stream<List<PartyRow>> watchByIds(List<String> ids) {
    if (ids.isEmpty) {
      return Stream<List<PartyRow>>.value(const <PartyRow>[]);
    }
    final query = select(parties)..where((p) => p.id.isIn(ids));
    return query.watch().map((rows) {
      final byId = <String, PartyRow>{for (final r in rows) r.id: r};
      return ids
          .map((id) => byId[id])
          .whereType<PartyRow>()
          .toList(growable: false);
    });
  }

  Stream<PartyRow?> watchById(String id) {
    return (select(parties)..where((p) => p.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<PartyRow?> findById(String id) {
    return (select(parties)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  /// Upsert each fetched party. Flat batch — no children to reconcile.
  /// Server-fetched rows always have `syncPending=false` and clear any
  /// previous `syncError` (server is authoritative for these rows).
  Future<void> upsertPage(List<PartyDto> dtos) async {
    if (dtos.isEmpty) return;
    await batch((b) {
      for (final dto in dtos) {
        b.insert(
          parties,
          _partyCompanion(dto),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Upsert a single row optimistically while its mutation is in the
  /// outbox. Flags `syncPending=true` so the UI surfaces a pending
  /// badge. Called from the repo's `OfflineException` branch.
  Future<void> upsertLocal(PartyDto draft) async {
    await into(parties).insertOnConflictUpdate(
      _partyCompanion(draft, syncPending: true),
    );
  }

  /// Replace a local-id row with the server-issued one in a single
  /// transaction — keeps the visible list stable while the sync handler
  /// reconciles. Drops the old local row, upserts the server row with
  /// `syncPending=false` and `syncError=null`.
  Future<void> markSyncSucceeded(
    String localId,
    PartyDto serverDto,
  ) async {
    await transaction(() async {
      await (delete(parties)..where((p) => p.id.equals(localId))).go();
      await into(parties).insertOnConflictUpdate(
        _partyCompanion(serverDto, syncPending: false, clearSyncError: true),
      );
    });
  }

  /// Mark a pending row as dead-lettered. `syncPending` stays true so the
  /// badge remains visible (now red, not orange); the error message is
  /// stashed for the UI to surface.
  Future<void> markSyncFailed(String localId, String error) async {
    await (update(parties)..where((p) => p.id.equals(localId))).write(
      PartiesCompanion(
        syncError: Value<String?>(error),
        syncPending: const Value<bool>(true),
      ),
    );
  }

  Future<int> deleteAll() => delete(parties).go();

  PartiesCompanion _partyCompanion(
    PartyDto dto, {
    bool? syncPending,
    bool clearSyncError = false,
  }) {
    return PartiesCompanion(
      id: Value<String>(dto.id),
      name: Value<String>(dto.name),
      address: Value<String?>(dto.address),
      ownerName: Value<String?>(dto.ownerName),
      panNo: Value<String?>(dto.panNo),
      email: Value<String?>(dto.email),
      phone: Value<String?>(dto.phone),
      notes: Value<String?>(dto.notes),
      dateJoined: Value<DateTime?>(dto.dateJoined),
      latitude: Value<double?>(dto.latitude),
      longitude: Value<double?>(dto.longitude),
      status: Value<String>(dto.status),
      partyType: Value<String?>(dto.partyType),
      syncPending: syncPending == null
          ? const Value<bool>.absent()
          : Value<bool>(syncPending),
      syncError: clearSyncError
          ? const Value<String?>(null)
          : const Value<String?>.absent(),
    );
  }
}
