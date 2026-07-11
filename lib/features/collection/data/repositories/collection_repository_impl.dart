import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/daos/collections_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/outbox_dao.dart';
import 'package:sales_sphere_erp/core/db/tables/collections_table.dart';
import 'package:sales_sphere_erp/core/db/tables/mutation_outbox_table.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/core/utils/uuid.dart';
import 'package:sales_sphere_erp/features/collection/data/collection_api.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';
import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collections_page.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection/domain/repositories/collection_repository.dart';

/// Logical operation key for `POST /collections`. Must match the `operation`
/// getter on `CollectionSyncHandler` so the drain can route the response back
/// into drift.
const String kCollectionCreateOperation = 'collection.create';

const int _kCollectionsPageSize = 15;

class CollectionRepositoryImpl implements CollectionRepository {
  CollectionRepositoryImpl({
    required CollectionApi api,
    required CollectionsDao dao,
    required OutboxDao outbox,
  }) : _api = api,
       _dao = dao,
       _outbox = outbox;

  final CollectionApi _api;
  final CollectionsDao _dao;
  final OutboxDao _outbox;

  @override
  Future<CollectionsPage> getCollectionsPage({
    int limit = _kCollectionsPageSize,
    String? cursor,
    String? search,
    PaymentMode? paymentMode,
    PaymentMode? excludePaymentMode,
    ChequeStatus? chequeStatus,
    CollectionStatus? status,
    String? createdById,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final page = await _api.list(
      limit: limit,
      cursor: cursor,
      search: search,
      paymentMode: paymentMode == null ? null : paymentModeToWire(paymentMode),
      excludePaymentMode: excludePaymentMode == null
          ? null
          : paymentModeToWire(excludePaymentMode),
      chequeStatus: chequeStatus == null
          ? null
          : chequeStatusToWire(chequeStatus),
      status: status == null ? null : collectionStatusToWire(status),
      createdById: createdById,
      fromDate: fromDate,
      toDate: toDate,
    );
    await _dao.upsertPage(CollectionKind.onAccount, page.items);
    return CollectionsPage(
      items: page.items.map(_toDomain).toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<Collection?> getCollectionById(String id) async {
    final cached = await _dao.findById(id);
    if (cached != null) return _rowToDomain(cached);
    // A local_<uuid> row that isn't in drift can't exist on the server either.
    if (id.startsWith('local_')) return null;
    try {
      final dto = await _api.getById(id);
      await _dao.upsertPage(CollectionKind.onAccount, <CollectionDto>[dto]);
      return _toDomain(dto);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Collection> addCollection(Collection draft) async {
    // One UUID does double duty: it keys the outbox row AND rides in the body
    // as `clientRequestId`, which is what makes the eventual POST idempotent.
    // It must be a bare v4 UUID — the server validates the format — so the
    // `local_` prefix goes on the drift id only, never on the key.
    final requestId = generateUuidV4();
    final dto = _toDto(draft, clientRequestId: requestId);

    final Collection domain;
    final Map<int, String> failures;
    try {
      final created = await _api.create(dto);
      await _dao.upsertPage(CollectionKind.onAccount, <CollectionDto>[created]);

      failures = await _uploadProofs(
        collectionId: created.id,
        filePaths: draft.imagePaths,
      );
      // Proofs land as a separate multipart call, so the row we just cached
      // doesn't know about them yet. Refetch rather than trusting the upload
      // response, which returns a different (0-indexed) image shape.
      domain = failures.length == draft.imagePaths.length
          ? _toDomain(created)
          : await _refetch(created.id) ?? _toDomain(created);
    } on DioException catch (e) {
      // Only the offline branch queues. Every other failure — 4xx, 5xx,
      // timeout, malformed envelope — bubbles up so the form can surface it.
      // Without connectivity the request never left the device, so there's no
      // risk of double-writing.
      if (e.error is! OfflineException) _throwWriteError(e);
      return _queueOfflineCreate(dto, requestId);
    }

    if (failures.isNotEmpty) {
      throw PartialImageUploadException(
        collection: domain,
        failures: failures,
      );
    }
    return domain;
  }

  /// Cache the receipt optimistically and hand the create to the outbox.
  ///
  /// Payment-proof images are dropped on this path — the outbox carries JSON,
  /// not binaries. The receipt itself (the money) still syncs, which is what
  /// matters in the field.
  Future<Collection> _queueOfflineCreate(
    CollectionDto dto,
    String requestId,
  ) async {
    final localId = 'local_$requestId';
    final local = dto.withId(localId);
    await _dao.upsertLocal(CollectionKind.onAccount, local);
    await _outbox.enqueue(
      MutationOutboxCompanion.insert(
        operation: kCollectionCreateOperation,
        method: 'POST',
        endpoint: Endpoints.collections,
        payloadJson: Value<String>(jsonEncode(local.toCreateJson())),
        idempotencyKey: requestId,
        localEntityId: Value<String?>(localId),
        // The backend is the final say on a collection: it re-derives the
        // customer's balance at write time and may refuse a receipt that was
        // valid when the rep recorded it. A rejection is surfaced, never
        // silently reconciled away.
        conflictPolicy: const Value<ConflictPolicy>(
          ConflictPolicy.serverAuthoritative,
        ),
      ),
    );
    return _toDomain(local).copyWith(syncPending: true);
  }

  @override
  Future<Collection> updateCollection(Collection collection) async {
    try {
      final updated = await _api.update(_toDto(collection));
      await _dao.upsertPage(CollectionKind.onAccount, <CollectionDto>[updated]);

      final failures = await _uploadProofs(
        collectionId: updated.id,
        filePaths: collection.imagePaths,
      );
      final domain = collection.imagePaths.isEmpty
          ? _toDomain(updated)
          : await _refetch(updated.id) ?? _toDomain(updated);

      if (failures.isNotEmpty) {
        throw PartialImageUploadException(
          collection: domain,
          failures: failures,
        );
      }
      return domain;
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  @override
  Future<void> deleteCollection(String id) async {
    try {
      await _api.delete(id);
      await _dao.deleteById(id);
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  @override
  Future<Collection> updateChequeStatus({
    required String id,
    required ChequeStatus status,
  }) async {
    try {
      final updated = await _api.updateChequeStatus(
        id: id,
        status: chequeStatusToWire(status),
      );
      await _dao.upsertPage(CollectionKind.onAccount, <CollectionDto>[updated]);
      return _toDomain(updated);
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  @override
  Future<List<String>> getBankNames() => _api.bankNames();

  @override
  Future<void> uploadImage({
    required String collectionId,
    required String filePath,
    required int slot,
  }) => _api.uploadImage(
    collectionId: collectionId,
    filePath: filePath,
    imageNumber: slot,
  );

  @override
  Future<void> removeImage({
    required String collectionId,
    required int slot,
  }) => _api.removeImage(collectionId: collectionId, imageNumber: slot);

  /// Best-effort proof upload: slot `i + 1` per picked file. A failure here
  /// must not lose the receipt — the money is already recorded — so failures
  /// are collected and reported, not thrown.
  Future<Map<int, String>> _uploadProofs({
    required String collectionId,
    required List<String> filePaths,
  }) async {
    final failures = <int, String>{};
    for (var i = 0; i < filePaths.length; i++) {
      try {
        await _api.uploadImage(
          collectionId: collectionId,
          filePath: filePaths[i],
          imageNumber: i + 1,
        );
      } on DioException catch (e) {
        failures[i + 1] = extractBackendErrorMessage(e) ?? 'Upload failed';
      }
    }
    return failures;
  }

  Future<Collection?> _refetch(String id) async {
    try {
      final fresh = await _api.getById(id);
      await _dao.upsertPage(CollectionKind.onAccount, <CollectionDto>[fresh]);
      return _toDomain(fresh);
    } on DioException {
      // The write already succeeded; a failed refetch is cosmetic.
      return null;
    }
  }

  /// Re-throw a write failure as the app's [ApiException] hierarchy,
  /// preferring the backend's specific copy over the interceptor's generic
  /// fallback.
  ///
  /// This is what surfaces the messages that actually matter here — the
  /// coverage-short 422, "Only DRAFT collections can be updated", the illegal
  /// cheque-transition 409, and the missing-ledger 422 on post.
  Never _throwWriteError(DioException e) {
    final backendMsg = extractBackendErrorMessage(e);
    final mapped = e.error;
    if (mapped is ApiException) {
      if (backendMsg == null || backendMsg == mapped.message) throw mapped;
      switch (mapped) {
        case ValidationException():
          throw ValidationException(
            backendMsg,
            fieldErrors: mapped.fieldErrors,
            statusCode: mapped.statusCode ?? 422,
          );
        case ForbiddenException():
          throw ForbiddenException(backendMsg);
        case NotFoundException():
          throw NotFoundException(backendMsg);
        case ServerException():
          throw ServerException(backendMsg, mapped.statusCode ?? 500);
        case NetworkException():
          throw NetworkException(backendMsg, statusCode: mapped.statusCode);
        default:
          throw mapped;
      }
    }
    throw e;
  }

  // ── Mappers ───────────────────────────────────────────────────────────────

  Collection _toDomain(CollectionDto dto) => Collection(
    id: dto.id,
    collectionNo: dto.collectionNo,
    party: CollectionParty(
      id: dto.customer.id,
      name: dto.customer.name,
      address: dto.customer.address ?? '',
      ownerName: dto.customer.ownerName ?? '',
    ),
    amount: dto.amount,
    receivedDate: dto.receivedDate,
    paymentMode: paymentModeFromWire(dto.paymentMode),
    status: collectionStatusFromWire(dto.status),
    bankName: dto.bankName,
    chequeNumber: dto.chequeNumber,
    chequeDate: dto.chequeDate,
    chequeStatus: dto.chequeStatus == null
        ? null
        : chequeStatusFromWire(dto.chequeStatus!),
    description: dto.description ?? '',
    imageUrls: dto.images.map((i) => i.imageUrl).toList(growable: false),
    createdByName: dto.createdBy?.name,
    createdAt: dto.createdAt,
  );

  Collection _rowToDomain(CollectionRow row) => collectionRowToDomain(row);

  CollectionDto _toDto(Collection c, {String? clientRequestId}) => CollectionDto(
    id: c.id,
    collectionNo: c.collectionNo,
    customer: CollectionCustomerDto(
      id: c.party.id,
      name: c.party.name,
      address: c.party.address,
      ownerName: c.party.ownerName,
    ),
    amount: c.amount,
    receivedDate: c.receivedDate,
    paymentMode: paymentModeToWire(c.paymentMode),
    status: collectionStatusToWire(c.status),
    bankName: c.bankName,
    chequeNumber: c.chequeNumber,
    chequeDate: c.chequeDate,
    chequeStatus: c.chequeStatus == null
        ? null
        : chequeStatusToWire(c.chequeStatus!),
    description: c.description.isEmpty ? null : c.description,
    images: const <CollectionImageDto>[],
    createdAt: c.createdAt,
    clientRequestId: clientRequestId,
  );
}

/// Drift row → domain. Top-level because the reactive list provider maps
/// straight off the `watchByIds` stream and must not reach into the repository
/// to do it — but the mapping has to stay identical in both places, so there's
/// exactly one copy.
///
/// This is the only mapper that carries [Collection.syncPending] /
/// [Collection.syncError]: they're device state, and the wire knows nothing
/// about them.
Collection collectionRowToDomain(CollectionRow row) => Collection(
  id: row.id,
  collectionNo: row.collectionNo,
  party: CollectionParty(
    id: row.customerId,
    name: row.customerName,
    address: row.customerAddress ?? '',
    ownerName: row.customerOwnerName ?? '',
  ),
  amount: row.amount,
  receivedDate: row.receivedDate,
  paymentMode: paymentModeFromWire(row.paymentMode),
  status: collectionStatusFromWire(row.status),
  bankName: row.bankName,
  chequeNumber: row.chequeNumber,
  chequeDate: row.chequeDate,
  chequeStatus: row.chequeStatus == null
      ? null
      : chequeStatusFromWire(row.chequeStatus!),
  description: row.description ?? '',
  imageUrls: CollectionsDao.decodeImages(
    row.imagesJson,
  ).map((i) => i.imageUrl).toList(growable: false),
  createdByName: row.createdByName,
  syncPending: row.syncPending,
  syncError: row.syncError,
  createdAt: row.createdAt,
);

// ── Wire codecs ─────────────────────────────────────────────────────────────
// The API speaks SCREAMING_SNAKE; the domain enums carry only display labels.
// Mapping lives here — one place, both directions — rather than polluting the
// domain with wire concerns. Top-level so the sync handler can reuse them.

String paymentModeToWire(PaymentMode mode) => switch (mode) {
  PaymentMode.cash => 'CASH',
  PaymentMode.cheque => 'CHEQUE',
  PaymentMode.bankTransfer => 'BANK_TRANSFER',
  PaymentMode.qrPay => 'QR_PAY',
};

PaymentMode paymentModeFromWire(String wire) => switch (wire) {
  'CASH' => PaymentMode.cash,
  'CHEQUE' => PaymentMode.cheque,
  'BANK_TRANSFER' => PaymentMode.bankTransfer,
  'QR_PAY' => PaymentMode.qrPay,
  _ => throw FormatException('Unsupported payment mode: $wire'),
};

String chequeStatusToWire(ChequeStatus status) => switch (status) {
  ChequeStatus.pending => 'PENDING',
  ChequeStatus.deposited => 'DEPOSITED',
  ChequeStatus.cleared => 'CLEARED',
  ChequeStatus.bounced => 'BOUNCED',
};

ChequeStatus chequeStatusFromWire(String wire) => switch (wire) {
  'PENDING' => ChequeStatus.pending,
  'DEPOSITED' => ChequeStatus.deposited,
  'CLEARED' => ChequeStatus.cleared,
  'BOUNCED' => ChequeStatus.bounced,
  _ => throw FormatException('Unsupported cheque status: $wire'),
};

String collectionStatusToWire(CollectionStatus status) => switch (status) {
  CollectionStatus.draft => 'DRAFT',
  CollectionStatus.posted => 'POSTED',
  CollectionStatus.cancelled => 'CANCELLED',
};

CollectionStatus collectionStatusFromWire(String wire) => switch (wire) {
  'DRAFT' => CollectionStatus.draft,
  'POSTED' => CollectionStatus.posted,
  'CANCELLED' => CollectionStatus.cancelled,
  _ => throw FormatException('Unsupported collection status: $wire'),
};

/// Exposes the abstract type so consumers depend on the contract, not the
/// impl. Tests override this with a fake `CollectionRepository`.
final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepositoryImpl(
    api: ref.watch(collectionApiProvider),
    dao: ref.watch(collectionsDaoProvider),
    outbox: ref.watch(outboxDaoProvider),
  );
});
