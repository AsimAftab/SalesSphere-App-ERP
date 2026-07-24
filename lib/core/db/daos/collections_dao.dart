import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/daos/parties_dao.dart' show PartiesDao;
import 'package:sales_sphere_erp/core/db/tables/collections_table.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';

part 'collections_dao.g.dart';

/// Drift cache for both collection modules, discriminated by
/// [CollectionKind]. Mirrors [PartiesDao]: the network upserts rows here and
/// the UI reads them back through a `watch` stream, so a sync-handler write
/// re-renders the list without the page knowing sync happened.
@DriftAccessor(tables: <Type>[Collections, CollectionAllocations])
class CollectionsDao extends DatabaseAccessor<AppDatabase>
    with _$CollectionsDaoMixin {
  CollectionsDao(super.db);

  /// Watch a list of collection ids, preserving caller-supplied order.
  ///
  /// `WHERE id IN (...)` returns rows in arbitrary order, so we re-key by id
  /// in Dart — the server's ordering (newest first) is authoritative and the
  /// rendered list must not reshuffle on every drift emit.
  Stream<List<CollectionRow>> watchByIds(List<String> ids) {
    if (ids.isEmpty) {
      return Stream<List<CollectionRow>>.value(const <CollectionRow>[]);
    }
    final query = select(collections)..where((c) => c.id.isIn(ids));
    return query.watch().map((rows) {
      final byId = <String, CollectionRow>{for (final r in rows) r.id: r};
      return ids
          .map((id) => byId[id])
          .whereType<CollectionRow>()
          .toList(growable: false);
    });
  }

  Stream<CollectionRow?> watchById(String id) =>
      (select(collections)..where((c) => c.id.equals(id))).watchSingleOrNull();

  Future<CollectionRow?> findById(String id) =>
      (select(collections)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Allocations for one Collection Plus row, in the server's returned order.
  /// Always empty for an on-account collection.
  Future<List<CollectionAllocationRow>> allocationsFor(String collectionId) =>
      (select(collectionAllocations)
            ..where((a) => a.collectionId.equals(collectionId)))
          .get();

  Stream<List<CollectionAllocationRow>> watchAllocationsFor(
    String collectionId,
  ) =>
      (select(collectionAllocations)
            ..where((a) => a.collectionId.equals(collectionId)))
          .watch();

  /// Upsert a freshly-fetched page. Server rows are authoritative: they clear
  /// any previous `syncError` and land with `syncPending = false`.
  Future<void> upsertPage(CollectionKind kind, List<CollectionDto> dtos) async {
    if (dtos.isEmpty) return;
    await transaction(() async {
      for (final dto in dtos) {
        await into(collections).insertOnConflictUpdate(
          _companion(kind, dto, syncPending: false, clearSyncError: true),
        );
        await _replaceAllocations(dto.id, _allocationsOf(dto));
      }
    });
  }

  /// Optimistically cache a row whose create is still sitting in the outbox.
  /// Flags `syncPending` so the card paints an orange `cloud_off` badge.
  Future<void> upsertLocal(CollectionKind kind, CollectionDto draft) async {
    await transaction(() async {
      await into(collections).insertOnConflictUpdate(
        _companion(kind, draft, syncPending: true),
      );
      await _replaceAllocations(draft.id, _allocationsOf(draft));
    });
  }

  /// Swap a `local_<uuid>` row for the server-issued one in a single
  /// transaction, so the visible list never blinks through an empty state.
  ///
  /// The server's row is the truth — including its `allocations`, which may
  /// differ from what the client previewed if balances moved while the
  /// mutation sat in the outbox.
  Future<void> markSyncSucceeded(
    String localId,
    CollectionKind kind,
    CollectionDto serverDto,
  ) async {
    await transaction(() async {
      await (delete(collectionAllocations)
            ..where((a) => a.collectionId.equals(localId)))
          .go();
      await (delete(collections)..where((c) => c.id.equals(localId))).go();
      await into(collections).insertOnConflictUpdate(
        _companion(kind, serverDto, syncPending: false, clearSyncError: true),
      );
      await _replaceAllocations(serverDto.id, _allocationsOf(serverDto));
    });
  }

  /// Flag a row the sync drain gave up on. `syncPending` stays true so the
  /// badge remains — it just turns from orange to red — and [error] carries
  /// the server's own copy.
  ///
  /// This is the server-authoritative rejection surface. A Collection Plus
  /// receipt allocated offline against a balance that moved comes back 422
  /// with "Selected invoices cover only Rs X…", and that lands here verbatim
  /// for the rep to act on. Do not silently re-allocate to make it fit.
  Future<void> markSyncFailed(String localId, String error) async {
    await (update(collections)..where((c) => c.id.equals(localId))).write(
      CollectionsCompanion(
        syncError: Value<String?>(error),
        syncPending: const Value<bool>(true),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    await transaction(() async {
      await (delete(collectionAllocations)
            ..where((a) => a.collectionId.equals(id)))
          .go();
      await (delete(collections)..where((c) => c.id.equals(id))).go();
    });
  }

  Future<int> deleteAll() async {
    await delete(collectionAllocations).go();
    return delete(collections).go();
  }

  /// Allocations exist only on a Collection Plus row. A plain Collection is an
  /// on-account receipt booked against the party, not against any invoice.
  static List<CollectionAllocationDto> _allocationsOf(CollectionDto dto) =>
      dto.allocations;

  /// Allocations are a pure mirror of the server's answer, so replace rather
  /// than merge — a re-post can move money between invoices, and a stale slice
  /// left behind would silently double-count.
  Future<void> _replaceAllocations(
    String collectionId,
    List<CollectionAllocationDto> allocations,
  ) async {
    await (delete(collectionAllocations)
          ..where((a) => a.collectionId.equals(collectionId)))
        .go();
    if (allocations.isEmpty) return;
    await batch((b) {
      b.insertAll(
        collectionAllocations,
        allocations.map(
          (a) => CollectionAllocationsCompanion.insert(
            collectionId: collectionId,
            invoiceId: a.invoiceId,
            invoiceNumber: a.invoiceNumber,
            amount: a.amount,
          ),
        ),
      );
    });
  }

  /// Sync columns default to [Value.absent] so a network upsert can't clobber
  /// the pending/error flags of a row that still has a queued mutation.
  ///
  /// `status` / `voucherId` / allocations are **Collection Plus only** — a plain
  /// Collection is a CRM record with no ledger, so `/collections` doesn't return
  /// them and those columns stay null for `onAccount` rows.
  CollectionsCompanion _companion(
    CollectionKind kind,
    CollectionDto dto, {
    bool? syncPending,
    bool clearSyncError = false,
  }) {
    final plus = dto;
    return CollectionsCompanion(
      id: Value<String>(dto.id),
      kind: Value<CollectionKind>(kind),
      collectionNo: Value<String>(dto.collectionNo),
      customerId: Value<String>(dto.customer.id),
      customerName: Value<String>(dto.customer.name),
      customerAddress: Value<String?>(dto.customer.address),
      customerOwnerName: Value<String?>(dto.customer.ownerName),
      amount: Value<double>(dto.amount),
      receivedDate: Value<DateTime>(dto.receivedDate),
      receivedDateBs: Value<String>(dto.receivedDateBS),
      paymentMode: Value<String>(dto.paymentMode),
      bankName: Value<String?>(dto.bankName),
      chequeNumber: Value<String?>(dto.chequeNumber),
      chequeDate: Value<DateTime?>(dto.chequeDate),
      chequeStatus: Value<String?>(dto.chequeStatus),
      description: Value<String?>(dto.description),
      status: Value<String?>(plus.status),
      voucherId: Value<String?>(plus.voucherId),
      createdById: Value<String?>(dto.createdBy?.id),
      createdByName: Value<String?>(dto.createdBy?.name),
      createdAt: Value<DateTime>(dto.createdAt),
      imagesJson: Value<String>(_encodeImages(dto.images)),
      syncPending: syncPending == null
          ? const Value<bool>.absent()
          : Value<bool>(syncPending),
      syncError: clearSyncError
          ? const Value<String?>(null)
          : const Value<String?>.absent(),
    );
  }

  static String _encodeImages(List<CollectionImageDto> images) => jsonEncode(
    images
        .map(
          (i) => <String, dynamic>{
            'imageNumber': i.imageNumber,
            'imageUrl': i.imageUrl,
          },
        )
        .toList(growable: false),
  );

  /// Decode the stored `images[]` blob back into DTOs. Static so the
  /// repository's row mapper can reuse it.
  static List<CollectionImageDto> decodeImages(String raw) {
    if (raw.isEmpty) return const <CollectionImageDto>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <CollectionImageDto>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(CollectionImageDto.fromJson)
        .toList(growable: false);
  }
}
