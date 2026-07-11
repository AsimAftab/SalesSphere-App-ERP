import 'package:sales_sphere_erp/features/collection/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collections_page.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/invoice_due.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_mode.dart';

/// Thrown when the receipt was created but a payment-proof upload failed.
/// Carries the created [collection] so the UI can still show the row — the
/// money is recorded, only the photo is missing.
class PartialImageUploadException implements Exception {
  const PartialImageUploadException({
    required this.collection,
    required this.failures,
  });

  final CollectionPlus collection;
  final Map<int, String> failures;

  List<int> get failedSlots => failures.keys.toList()..sort();

  String get firstMessage =>
      failures.isEmpty ? 'Upload failed' : failures.values.first;

  @override
  String toString() =>
      'PartialImageUploadException(collection=${collection.id}, '
      'failures=$failures)';
}

/// Domain-side contract for invoice-allocated collections.
abstract class CollectionPlusRepository {
  Future<CollectionPlusPage> getCollectionsPage({
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

  Future<CollectionPlus?> getCollectionById(String id);

  /// The party's unsettled invoices, **oldest-first with fully-paid rows
  /// dropped** — the same order the server's FIFO uses.
  ///
  /// [excludeCollectionId] is **mandatory when editing**. It releases that
  /// receipt's own allocations back into the pool; without it the collection
  /// being edited still holds down the money it's about to re-allocate, and
  /// re-saving it unchanged fails validation every time.
  ///
  /// Only POSTED invoices are collectible. An empty list means "nothing to
  /// settle yet", not a bug — a rep's order sits DRAFT until the web app posts
  /// it, and on-account `/collections` is the escape hatch until then.
  Future<List<InvoiceDue>> getOutstandingInvoices({
    required String partyId,
    String? excludeCollectionId,
  });

  /// Re-hydrate specific invoices by id, keeping rows that are already fully
  /// paid — so an invoice this receipt settled still renders in the edit
  /// picker.
  Future<List<InvoiceDue>> getInvoiceMeta({
    required List<String> invoiceIds,
    String? excludeCollectionId,
  });

  /// Record a receipt against [invoiceIds].
  ///
  /// The client sends the **selection, never a split**. The server runs FIFO
  /// against live balances and returns the authoritative allocations. If the
  /// selection no longer covers the amount, it refuses with a 422 rather than
  /// re-allocating — surface that, don't paper over it.
  Future<CollectionPlus> addCollection(
    CollectionPlus draft, {
    required List<String> invoiceIds,
  });

  Future<CollectionPlus> updateCollection(
    CollectionPlus collection, {
    required List<String> invoiceIds,
  });

  Future<void> deleteCollection(String id);

  Future<CollectionPlus> updateChequeStatus({
    required String id,
    required ChequeStatus status,
  });

  Future<List<String>> getBankNames();

  Future<void> uploadImage({
    required String collectionId,
    required String filePath,
    required int slot,
  });

  Future<void> removeImage({required String collectionId, required int slot});
}
