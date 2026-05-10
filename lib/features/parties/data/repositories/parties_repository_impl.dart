import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/daos/outbox_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/parties_dao.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/core/utils/uuid.dart';
import 'package:sales_sphere_erp/features/parties/data/dto/party_dto.dart';
import 'package:sales_sphere_erp/features/parties/data/dto/party_image_ref.dart';
import 'package:sales_sphere_erp/features/parties/data/parties_api.dart';
import 'package:sales_sphere_erp/features/parties/domain/parties_page.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/domain/repositories/parties_repository.dart';

/// Logical operation key for `POST /customers`. Must match the
/// `operation` getter on `PartiesSyncHandler` so the sync service can
/// route 2xx/4xx responses back into drift.
const String kPartiesCreateOperation = 'parties.create';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO ↔ domain mapping happens here. Drift is the read-side cache:
/// every successful list/byId fetch is upserted, and `getPartyById`
/// consults drift before falling back to the network.
///
/// `addParty` is offline-tolerant: a `DioException` carrying an
/// `OfflineException` triggers the optimistic-insert + outbox-enqueue
/// path so the user sees their write immediately. The sync handler
/// reconciles the server response back into drift via
/// `PartiesDao.markSyncSucceeded`.
class PartiesRepositoryImpl implements PartiesRepository {
  PartiesRepositoryImpl({
    required PartiesApi api,
    required PartiesDao dao,
    required OutboxDao outbox,
  })  : _api = api,
        _dao = dao,
        _outbox = outbox;

  final PartiesApi _api;
  final PartiesDao _dao;
  final OutboxDao _outbox;

  @override
  Future<PartiesPage> getPartiesPage({
    int limit = 20,
    String? cursor,
    String? search,
  }) async {
    final pageDto = await _api.list(
      limit: limit,
      cursor: cursor,
      search: search,
    );
    await _dao.upsertPage(pageDto.items);
    final domain = pageDto.items.map(_toDomain).toList(growable: false);
    return PartiesPage(items: domain, nextCursor: pageDto.nextCursor);
  }

  @override
  Future<Party?> getPartyById(String id) async {
    final cached = await _dao.findById(id);
    if (cached != null) return _rowToDomain(cached);
    try {
      final dto = await _api.getById(id);
      await _dao.upsertPage(<PartyDto>[dto]);
      return _toDomain(dto);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Party> addParty(Party draft) async {
    final dto = _toDto(draft);
    final Party domain;
    final Map<int, String> failures;
    try {
      final created = await _api.create(dto);
      await _dao.upsertPage(<PartyDto>[created]);
      // Best-effort image upload: each local file goes to slot i+1.
      // Failures are collected with the backend's actual error message
      // so the form can show a useful snackbar instead of just a
      // count.
      failures = <int, String>{};
      for (var i = 0; i < draft.imagePaths.length; i++) {
        try {
          await _api.uploadImage(
            customerId: created.id,
            filePath: draft.imagePaths[i],
            imageNumber: i + 1,
          );
        } on DioException catch (e) {
          failures[i + 1] = extractBackendErrorMessage(e) ?? 'Upload failed';
        }
      }
      domain = _toDomain(created);
    } on DioException catch (e) {
      // Only the offline branch enqueues; every other failure (4xx, 5xx,
      // timeout, malformed envelope) bubbles up so the form can surface
      // it. Without connectivity the request never leaves the device, so
      // there's no risk of double-writing.
      if (e.error is! OfflineException) rethrow;
      // Images are dropped on the offline path — binary outbox is
      // future work. The customer record itself still queues.
      return _queueOfflineCreate(dto);
    }
    if (failures.isNotEmpty) {
      throw PartialImageUploadException(party: domain, failures: failures);
    }
    return domain;
  }

  Future<Party> _queueOfflineCreate(PartyDto dto) async {
    final localId = 'local_${generateUuidV4()}';
    final local = dto.withId(localId);
    await _dao.upsertLocal(local);
    await _outbox.enqueue(
      MutationOutboxCompanion.insert(
        operation: kPartiesCreateOperation,
        method: 'POST',
        endpoint: Endpoints.customers,
        payloadJson: Value<String>(jsonEncode(local.toJson())),
        idempotencyKey: localId,
        localEntityId: Value<String?>(localId),
      ),
    );
    return _toDomain(local).copyWith(syncPending: true);
  }

  @override
  Future<Party> updateParty(Party party) async {
    final updated = await _api.update(_toDto(party));
    await _dao.upsertPage(<PartyDto>[updated]);
    return _toDomain(updated);
  }

  @override
  Future<List<String>> getPartyTypes() => _api.partyTypes();

  @override
  Future<List<PartyImageRef>> listImages(String customerId) =>
      _api.listImages(customerId);

  @override
  Future<void> uploadImage({
    required String customerId,
    required String filePath,
    required int slot,
  }) =>
      _api.uploadImage(
        customerId: customerId,
        filePath: filePath,
        imageNumber: slot,
      );

  @override
  Future<void> removeImage({
    required String customerId,
    required int slot,
  }) =>
      _api.removeImage(customerId: customerId, imageNumber: slot);

  // ── Mappers ───────────────────────────────────────────────────────────────
  // DTOs stay nullable for wire compatibility; the domain marks owner +
  // phone + panVat non-null because the form's validators require them.
  // Records without these surface as empty strings; the form forces the
  // user to fill them on save.

  Party _toDomain(PartyDto dto) {
    return Party(
      id: dto.id,
      name: dto.name,
      address: dto.address ?? '',
      ownerName: dto.ownerName ?? '',
      panVat: dto.panNo ?? '',
      phone: dto.phone ?? '',
      email: dto.email,
      dateJoined: dto.dateJoined,
      partyType: dto.partyType,
      notes: dto.notes,
      latitude: dto.latitude,
      longitude: dto.longitude,
      status: dto.status,
      // DTOs come from the wire — sync columns aren't part of the wire
      // shape. Drift owns those, populated in _rowToDomain.
    );
  }

  Party _rowToDomain(PartyRow row) {
    return Party(
      id: row.id,
      name: row.name,
      address: row.address ?? '',
      ownerName: row.ownerName ?? '',
      panVat: row.panNo ?? '',
      phone: row.phone ?? '',
      email: row.email,
      dateJoined: row.dateJoined,
      partyType: row.partyType,
      notes: row.notes,
      latitude: row.latitude,
      longitude: row.longitude,
      status: row.status,
      syncPending: row.syncPending,
      syncError: row.syncError,
    );
  }

  PartyDto _toDto(Party p) {
    return PartyDto(
      id: p.id,
      name: p.name,
      ownerName: p.ownerName.isEmpty ? null : p.ownerName,
      panNo: p.panVat.isEmpty ? null : p.panVat,
      phone: p.phone.isEmpty ? null : p.phone,
      email: p.email,
      notes: p.notes,
      address: p.address.isEmpty ? null : p.address,
      latitude: p.latitude,
      longitude: p.longitude,
      dateJoined: p.dateJoined,
      status: p.status ?? 'ACTIVE',
      partyType: p.partyType,
    );
  }
}

/// Exposes the abstract type so consumers depend on the contract, not the
/// impl class. Tests override this provider with a fake `PartiesRepository`.
final partiesRepositoryProvider = Provider<PartiesRepository>((ref) {
  return PartiesRepositoryImpl(
    api: ref.watch(partiesApiProvider),
    dao: ref.watch(partiesDaoProvider),
    outbox: ref.watch(outboxDaoProvider),
  );
});
