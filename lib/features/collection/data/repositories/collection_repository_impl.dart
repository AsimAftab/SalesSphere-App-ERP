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
import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart'
    as plus;
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_allocation.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_invoice.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collections_page.dart';
import 'package:sales_sphere_erp/features/collection/domain/invoice_due.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart'
    as plus;
import 'package:sales_sphere_erp/features/collection/domain/repositories/collection_repository.dart';

/// Logical operation key for `POST /collection-plus`.
const String kCollectionCreateOperation = 'collection.create';

const int _kCollectionPageSize = 15;

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
  Future<CollectionPage> getCollectionsPage({
    int limit = _kCollectionPageSize,
    String? cursor,
    String? search,
    plus.PaymentMode? paymentMode,
    plus.PaymentMode? excludePaymentMode,
    plus.ChequeStatus? chequeStatus,
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
      chequeStatus: chequeStatus == null ? null : chequeStatusToWire(chequeStatus),
      status: status == null ? null : collectionStatusToWire(status),
      createdById: createdById,
      fromDate: fromDate,
      toDate: toDate,
    );
    await _dao.upsertPage(CollectionKind.allocated, page.items);
    return CollectionPage(
      items: page.items.map(_toDomain).toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<Collection?> getCollectionById(String id) async {
    final cached = await _dao.findById(id);
    if (cached != null) {
      final allocations = await _dao.allocationsFor(id);
      return collectionRowToDomain(cached, allocations);
    }
    if (id.startsWith('local_')) return null;
    try {
      final dto = await _api.getById(id);
      await _dao.upsertPage(CollectionKind.allocated, <CollectionDto>[dto]);
      return _toDomain(dto);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<InvoiceDue>> getOutstandingInvoices({
    required String partyId,
    String? excludeCollectionId,
    DateTime? asOfDate,
  }) async {
    final dtos = await _api.outstandingForParty(
      partyId: partyId,
      excludeCollectionId: excludeCollectionId,
      asOfDate: asOfDate,
    );
    return dtos.map(_dueFromDto).toList(growable: false);
  }

  @override
  Future<List<InvoiceDue>> getInvoiceMeta({
    required List<String> invoiceIds,
    String? excludeCollectionId,
  }) async {
    final dtos = await _api.invoiceMeta(
      invoiceIds: invoiceIds,
      excludeCollectionId: excludeCollectionId,
    );
    return dtos.map(_dueFromDto).toList(growable: false);
  }

  @override
  Future<Collection> addCollection(
    Collection draft, {
    required List<String> invoiceIds,
  }) async {
    // One UUID keys the outbox row and rides in the body as `clientRequestId`,
    // which is what makes the eventual POST idempotent. It must be a bare v4
    // UUID (the server validates the format), so the `local_` prefix goes on
    // the drift id only.
    final requestId = generateUuidV4();
    final dto = _toDto(draft, clientRequestId: requestId);

    final Collection domain;
    final Map<int, String> failures;
    try {
      final created = await _api.create(dto, invoiceIds: invoiceIds);
      await _dao.upsertPage(CollectionKind.allocated, <CollectionDto>[created]);

      failures = await _uploadProofs(
        collectionId: created.id,
        filePaths: draft.imagePaths,
      );
      domain = failures.length == draft.imagePaths.length
          ? _toDomain(created)
          : await _refetch(created.id) ?? _toDomain(created);
    } on DioException catch (e) {
      if (e.error is! OfflineException) _throwWriteError(e);
      return _queueOfflineCreate(dto, requestId, invoiceIds);
    }

    if (failures.isNotEmpty) {
      throw PartialImageUploadException(
        collection: domain,
        failures: failures,
      );
    }
    return domain;
  }

  /// Cache optimistically and queue the create.
  ///
  /// The cached row carries **no allocations** — the server hasn't computed
  /// them yet, and inventing a local split would be a lie the UI would then
  /// render. The preview the rep saw was against balances that may already
  /// have moved; if they have, this mutation comes back 422 and the row gets a
  /// red badge carrying the server's coverage message.
  Future<Collection> _queueOfflineCreate(
    CollectionDto dto,
    String requestId,
    List<String> invoiceIds,
  ) async {
    final localId = 'local_$requestId';
    final local = dto.withId(localId);
    await _dao.upsertLocal(CollectionKind.allocated, local);
    await _outbox.enqueue(
      MutationOutboxCompanion.insert(
        operation: kCollectionCreateOperation,
        method: 'POST',
        endpoint: Endpoints.collection,
        payloadJson: Value<String>(
          jsonEncode(local.toCreateJson(invoiceIds: invoiceIds)),
        ),
        idempotencyKey: requestId,
        localEntityId: Value<String?>(localId),
        conflictPolicy: const Value<ConflictPolicy>(
          ConflictPolicy.serverAuthoritative,
        ),
      ),
    );
    return _toDomain(local).copyWith(syncPending: true);
  }

  @override
  Future<Collection> updateCollection(
    Collection collection, {
    required List<String> invoiceIds,
  }) async {
    try {
      final updated = await _api.update(
        _toDto(collection),
        invoiceIds: invoiceIds,
      );
      await _dao.upsertPage(CollectionKind.allocated, <CollectionDto>[updated]);

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
    required plus.ChequeStatus status,
  }) async {
    try {
      final updated = await _api.updateChequeStatus(
        id: id,
        status: chequeStatusToWire(status),
      );
      await _dao.upsertPage(CollectionKind.allocated, <CollectionDto>[updated]);
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
      await _dao.upsertPage(CollectionKind.allocated, <CollectionDto>[fresh]);
      return _toDomain(fresh);
    } on DioException {
      return null;
    }
  }

  /// Surface the backend's own copy rather than the interceptor's generic
  /// fallback. For this module the message that matters most is the
  /// coverage-short 422: "Selected invoices cover only Rs X. Select more to
  /// cover Rs Y." — the user needs to read that, not "Invalid request."
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

  InvoiceDue _dueFromDto(OutstandingInvoiceDto dto) => InvoiceDue(
    invoice: CollectionInvoice(
      id: dto.invoiceId,
      number: dto.invoiceNumber,
      amount: dto.totalAmount,
      invoiceDate: dto.invoiceDate,
    ),
    paid: dto.paid,
    outstanding: dto.outstanding,
    lastPaidOn: dto.lastPaidOn,
    priorPayments: dto.priorPayments
        .map(
          (PriorPaymentDto p) =>
              PriorPayment(amount: p.amount, receivedDate: p.receivedDate),
        )
        .toList(growable: false),
  );

  Collection _toDomain(CollectionDto dto) => Collection(
    id: dto.id,
    collectionNo: dto.collectionNo,
    allocations: dto.allocations
        .map(
          (a) => CollectionAllocation(
            invoiceId: a.invoiceId,
            invoiceNumber: a.invoiceNumber,
            amount: a.amount,
          ),
        )
        .toList(growable: false),
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

  CollectionDto _toDto(Collection c, {String? clientRequestId}) =>
      CollectionDto(
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

/// Drift row (+ its allocation rows) → domain. Top-level so the reactive list
/// provider can map straight off the `watchByIds` stream.
Collection collectionRowToDomain(
  CollectionRow row,
  List<CollectionAllocationRow> allocations,
) => Collection(
  id: row.id,
  collectionNo: row.collectionNo,
  allocations: allocations
      .map(
        (a) => CollectionAllocation(
          invoiceId: a.invoiceId,
          invoiceNumber: a.invoiceNumber,
          amount: a.amount,
        ),
      )
      .toList(growable: false),
  party: CollectionParty(
    id: row.customerId,
    name: row.customerName,
    address: row.customerAddress ?? '',
    ownerName: row.customerOwnerName ?? '',
  ),
  amount: row.amount,
  receivedDate: row.receivedDate,
  paymentMode: paymentModeFromWire(row.paymentMode),
  // `status` is nullable in drift (on-account rows have none); a Plus row
  // always carries one, so a missing value means a corrupt cache — default to
  // draft rather than crashing the list.
  status: row.status == null
      ? CollectionStatus.draft
      : collectionStatusFromWire(row.status!),
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
// Collection Plus is a separate feature and carries its own PaymentMode /
// ChequeStatus enums, so it needs its own codecs.
//
// These are written out as explicit switches rather than bridged through
// `Enum.index` to the sibling module's copies. Index-bridging would work today
// — both enums happen to declare their values in the same order — but it turns
// a future reordering of an unrelated enum into a silent mis-mapping of money,
// with no compile error. An exhaustive switch fails loudly instead.

String paymentModeToWire(plus.PaymentMode mode) => switch (mode) {
  plus.PaymentMode.cash => 'CASH',
  plus.PaymentMode.cheque => 'CHEQUE',
  plus.PaymentMode.bankTransfer => 'BANK_TRANSFER',
  plus.PaymentMode.qrPay => 'QR_PAY',
};

plus.PaymentMode paymentModeFromWire(String wire) => switch (wire) {
  'CASH' => plus.PaymentMode.cash,
  'CHEQUE' => plus.PaymentMode.cheque,
  'BANK_TRANSFER' => plus.PaymentMode.bankTransfer,
  'QR_PAY' => plus.PaymentMode.qrPay,
  _ => throw FormatException('Unsupported payment mode: $wire'),
};

String chequeStatusToWire(plus.ChequeStatus status) => switch (status) {
  plus.ChequeStatus.pending => 'PENDING',
  plus.ChequeStatus.deposited => 'DEPOSITED',
  plus.ChequeStatus.cleared => 'CLEARED',
  plus.ChequeStatus.bounced => 'BOUNCED',
};

/// Ledger lifecycle codecs — Collection Plus only. A plain Collection has no
/// status, because it never posts to a ledger.
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

plus.ChequeStatus chequeStatusFromWire(String wire) => switch (wire) {
  'PENDING' => plus.ChequeStatus.pending,
  'DEPOSITED' => plus.ChequeStatus.deposited,
  'CLEARED' => plus.ChequeStatus.cleared,
  'BOUNCED' => plus.ChequeStatus.bounced,
  _ => throw FormatException('Unsupported cheque status: $wire'),
};

final collectionRepositoryProvider = Provider<CollectionRepository>((
  ref,
) {
  return CollectionRepositoryImpl(
    api: ref.watch(collectionApiProvider),
    dao: ref.watch(collectionsDaoProvider),
    outbox: ref.watch(outboxDaoProvider),
  );
});
