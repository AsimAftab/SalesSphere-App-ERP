import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collections_page.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';

/// Thrown by [CollectionRepository.addCollection] when the receipt was created
/// but at least one payment-proof upload failed.
///
/// Carries the created [collection] so the caller can still reflect the new
/// row in the UI — the money is recorded, only the photo is missing — plus
/// per-slot [failures] keyed by 1-indexed slot with the backend's message.
class PartialImageUploadException implements Exception {
  const PartialImageUploadException({
    required this.collection,
    required this.failures,
  });

  final Collection collection;
  final Map<int, String> failures;

  /// 1-indexed slots that failed, sorted so the snackbar copy is stable.
  List<int> get failedSlots => failures.keys.toList()..sort();

  String get firstMessage =>
      failures.isEmpty ? 'Upload failed' : failures.values.first;

  @override
  String toString() =>
      'PartialImageUploadException(collection=${collection.id}, '
      'failures=$failures)';
}

/// Domain-side contract for on-account collections. The implementation (DTO
/// mapping, drift persistence, outbox enqueue) lives in
/// `data/repositories/collection_repository_impl.dart`.
abstract class CollectionRepository {
  /// Fetch one cursor-paginated slice, upserting it into drift so the
  /// reactive list re-renders.
  ///
  /// Filtering is **server-side**. [excludePaymentMode] is what separates the
  /// two list tabs: the main tab excludes `cheque`, the PDC tab selects it via
  /// [paymentMode]. [createdById] takes a user id. [fromDate] / [toDate]
  /// filter on creation time, matching the "Created From / To" labels.
  Future<CollectionsPage> getCollectionsPage({
    int limit,
    String? cursor,
    String? search,
    PaymentMode? paymentMode,
    PaymentMode? excludePaymentMode,
    ChequeStatus? chequeStatus,
    CollectionStatus? status,
    String? createdById,
    DateTime? fromDate,
    DateTime? toDate,
  });

  /// Drift-first single-row read, falling back to the API for cold-start
  /// deep-links. Returns `null` only when the row genuinely doesn't exist.
  Future<Collection?> getCollectionById(String id);

  /// Record a receipt. Lands `DRAFT` server-side.
  ///
  /// Offline, the row is cached optimistically and the create is queued in the
  /// outbox against a v4-UUID `clientRequestId`, which makes the eventual
  /// `POST` idempotent — a replay returns the original row rather than
  /// duplicating the receipt.
  ///
  /// Throws [PartialImageUploadException] when the receipt saved but a proof
  /// image didn't.
  Future<Collection> addCollection(Collection draft);

  /// Edit a draft. The server 409s once the row is POSTED or CANCELLED, and
  /// the party is immutable.
  Future<Collection> updateCollection(Collection collection);

  /// Delete a draft. The server refuses anything else — a posted receipt must
  /// be cancelled, which writes a reversal voucher.
  Future<void> deleteCollection(String id);

  /// Advance a cheque through its clearing lifecycle.
  ///
  /// Legal moves: `pending → deposited | cleared | bounced`,
  /// `deposited → cleared | bounced`. `cleared` and `bounced` are terminal;
  /// anything else is refused.
  ///
  /// On a POSTED receipt this moves real money: clearing writes a contra
  /// voucher (cheque-in-hand → bank), and bouncing writes a reversal that
  /// cancels the receipt and restores the customer's outstanding balance.
  Future<Collection> updateChequeStatus({
    required String id,
    required ChequeStatus status,
  });

  /// Bank catalogue for the cheque / bank-transfer picker. A **suggestion
  /// list**, not an enum — the field is free text and the picker offers an
  /// "add a different bank" escape hatch.
  Future<List<String>> getBankNames();

  /// Upload (or replace) one payment-proof slot, 1-indexed, max 2.
  Future<void> uploadImage({
    required String collectionId,
    required String filePath,
    required int slot,
  });

  /// Delete one payment-proof slot.
  Future<void> removeImage({required String collectionId, required int slot});
}
