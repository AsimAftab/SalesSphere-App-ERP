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
import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';
// `CollectionStatus` and its codecs are genuinely shared: the ledger lifecycle
// is the backend's, identical for both modules, and duplicating a
// DRAFT/POSTED/CANCELLED enum per feature would buy nothing.
import 'package:sales_sphere_erp/features/collection/data/repositories/collection_repository_impl.dart'
    show collectionStatusFromWire, collectionStatusToWire;
import 'package:sales_sphere_erp/features/collection/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection_plus/data/collection_plus_api.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/cheque_status.dart'
    as plus;
import 'package:sales_sphere_erp/features/collection_plus/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_allocation.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_invoice.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collections_page.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/invoice_due.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_mode.dart'
    as plus;
import 'package:sales_sphere_erp/features/collection_plus/domain/repositories/collection_plus_repository.dart';

/// Logical operation key for `POST /collection-plus`.
const String kCollectionPlusCreateOperation = 'collectionPlus.create';

const int _kCollectionPlusPageSize = 15;

class CollectionPlusRepositoryImpl implements CollectionPlusRepository {
  CollectionPlusRepositoryImpl({
    required CollectionPlusApi api,
    required CollectionsDao dao,
    required OutboxDao outbox,
  }) : _api = api,
       _dao = dao,
       _outbox = outbox;

  final CollectionPlusApi _api;
  final CollectionsDao _dao;
  final OutboxDao _outbox;

  @override
  Future<CollectionPlusPage> getCollectionsPage({
    int limit = _kCollectionPlusPageSize,
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
      paymentMode: paymentMode == null ? null : _modeToWire(paymentMode),
      excludePaymentMode: excludePaymentMode == null
          ? null
          : _modeToWire(excludePaymentMode),
      chequeStatus: chequeStatus == null ? null : _chequeToWire(chequeStatus),
      status: status == null ? null : collectionStatusToWire(status),
      createdById: createdById,
      fromDate: fromDate,
      toDate: toDate,
    );
    await _dao.upsertPage(CollectionKind.allocated, page.items);
    return CollectionPlusPage(
      items: page.items.map(_toDomain).toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<CollectionPlus?> getCollectionById(String id) async {
    final cached = await _dao.findById(id);
    if (cached != null) {
      final allocations = await _dao.allocationsFor(id);
      return collectionPlusRowToDomain(cached, allocations);
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
  }) async {
    final dtos = await _api.outstandingForParty(
      partyId: partyId,
      excludeCollectionId: excludeCollectionId,
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
  Future<CollectionPlus> addCollection(
    CollectionPlus draft, {
    required List<String> invoiceIds,
  }) async {
    // One UUID keys the outbox row and rides in the body as `clientRequestId`,
    // which is what makes the eventual POST idempotent. It must be a bare v4
    // UUID (the server validates the format), so the `local_` prefix goes on
    // the drift id only.
    final requestId = generateUuidV4();
    final dto = _toDto(draft, clientRequestId: requestId);

    final CollectionPlus domain;
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
  Future<CollectionPlus> _queueOfflineCreate(
    CollectionDto dto,
    String requestId,
    List<String> invoiceIds,
  ) async {
    final localId = 'local_$requestId';
    final local = dto.withId(localId);
    await _dao.upsertLocal(CollectionKind.allocated, local);
    await _outbox.enqueue(
      MutationOutboxCompanion.insert(
        operation: kCollectionPlusCreateOperation,
        method: 'POST',
        endpoint: Endpoints.collectionPlus,
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
  Future<CollectionPlus> updateCollection(
    CollectionPlus collection, {
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
  Future<CollectionPlus> updateChequeStatus({
    required String id,
    required plus.ChequeStatus status,
  }) async {
    try {
      final updated = await _api.updateChequeStatus(
        id: id,
        status: _chequeToWire(status),
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

  Future<CollectionPlus?> _refetch(String id) async {
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
    invoice: CollectionPlusInvoice(
      id: dto.invoiceId,
      number: dto.invoiceNumber,
      amount: dto.totalAmount,
      invoiceDate: dto.invoiceDate,
    ),
    paid: dto.paid,
    outstanding: dto.outstanding,
    lastPaidOn: dto.lastPaidOn,
  );

  CollectionPlus _toDomain(CollectionDto dto) => CollectionPlus(
    id: dto.id,
    collectionNo: dto.collectionNo,
    allocations: dto.allocations
        .map(
          (a) => CollectionPlusAllocation(
            invoiceId: a.invoiceId,
            invoiceNumber: a.invoiceNumber,
            amount: a.amount,
          ),
        )
        .toList(growable: false),
    party: CollectionPlusParty(
      id: dto.customer.id,
      name: dto.customer.name,
      address: dto.customer.address ?? '',
      ownerName: dto.customer.ownerName ?? '',
    ),
    amount: dto.amount,
    receivedDate: dto.receivedDate,
    paymentMode: _modeFromWire(dto.paymentMode),
    status: collectionStatusFromWire(dto.status),
    bankName: dto.bankName,
    chequeNumber: dto.chequeNumber,
    chequeDate: dto.chequeDate,
    chequeStatus: dto.chequeStatus == null
        ? null
        : _chequeFromWire(dto.chequeStatus!),
    description: dto.description ?? '',
    imageUrls: dto.images.map((i) => i.imageUrl).toList(growable: false),
    createdByName: dto.createdBy?.name,
    createdAt: dto.createdAt,
  );

  CollectionDto _toDto(CollectionPlus c, {String? clientRequestId}) =>
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
        paymentMode: _modeToWire(c.paymentMode),
        status: collectionStatusToWire(c.status),
        bankName: c.bankName,
        chequeNumber: c.chequeNumber,
        chequeDate: c.chequeDate,
        chequeStatus: c.chequeStatus == null
            ? null
            : _chequeToWire(c.chequeStatus!),
        description: c.description.isEmpty ? null : c.description,
        images: const <CollectionImageDto>[],
        createdAt: c.createdAt,
        clientRequestId: clientRequestId,
      );
}

/// Drift row (+ its allocation rows) → domain. Top-level so the reactive list
/// provider can map straight off the `watchByIds` stream.
CollectionPlus collectionPlusRowToDomain(
  CollectionRow row,
  List<CollectionAllocationRow> allocations,
) => CollectionPlus(
  id: row.id,
  collectionNo: row.collectionNo,
  allocations: allocations
      .map(
        (a) => CollectionPlusAllocation(
          invoiceId: a.invoiceId,
          invoiceNumber: a.invoiceNumber,
          amount: a.amount,
        ),
      )
      .toList(growable: false),
  party: CollectionPlusParty(
    id: row.customerId,
    name: row.customerName,
    address: row.customerAddress ?? '',
    ownerName: row.customerOwnerName ?? '',
  ),
  amount: row.amount,
  receivedDate: row.receivedDate,
  paymentMode: _modeFromWire(row.paymentMode),
  status: collectionStatusFromWire(row.status),
  bankName: row.bankName,
  chequeNumber: row.chequeNumber,
  chequeDate: row.chequeDate,
  chequeStatus: row.chequeStatus == null
      ? null
      : _chequeFromWire(row.chequeStatus!),
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

String _modeToWire(plus.PaymentMode mode) => switch (mode) {
  plus.PaymentMode.cash => 'CASH',
  plus.PaymentMode.cheque => 'CHEQUE',
  plus.PaymentMode.bankTransfer => 'BANK_TRANSFER',
  plus.PaymentMode.qrPay => 'QR_PAY',
};

plus.PaymentMode _modeFromWire(String wire) => switch (wire) {
  'CASH' => plus.PaymentMode.cash,
  'CHEQUE' => plus.PaymentMode.cheque,
  'BANK_TRANSFER' => plus.PaymentMode.bankTransfer,
  'QR_PAY' => plus.PaymentMode.qrPay,
  _ => throw FormatException('Unsupported payment mode: $wire'),
};

String _chequeToWire(plus.ChequeStatus status) => switch (status) {
  plus.ChequeStatus.pending => 'PENDING',
  plus.ChequeStatus.deposited => 'DEPOSITED',
  plus.ChequeStatus.cleared => 'CLEARED',
  plus.ChequeStatus.bounced => 'BOUNCED',
};

plus.ChequeStatus _chequeFromWire(String wire) => switch (wire) {
  'PENDING' => plus.ChequeStatus.pending,
  'DEPOSITED' => plus.ChequeStatus.deposited,
  'CLEARED' => plus.ChequeStatus.cleared,
  'BOUNCED' => plus.ChequeStatus.bounced,
  _ => throw FormatException('Unsupported cheque status: $wire'),
};

final collectionPlusRepositoryProvider = Provider<CollectionPlusRepository>((
  ref,
) {
  return CollectionPlusRepositoryImpl(
    api: ref.watch(collectionPlusApiProvider),
    dao: ref.watch(collectionsDaoProvider),
    outbox: ref.watch(outboxDaoProvider),
  );
});
