import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_allocation.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection/domain/repositories/collection_repository.dart';
// `collection_providers.dart` re-exports `collectionRepositoryProvider` so
// the controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/collection/presentation/providers/collection_providers.dart';

part 'collection_controller.g.dart';

/// Routes Collection Plus write actions from the UI through the repository.
/// Reads stay on `collectionListVisibleProvider` /
/// `collectionByIdProvider`.
@riverpod
class CollectionController extends _$CollectionController {
  @override
  void build() {}

  /// Record a receipt against the selected invoices.
  ///
  /// Takes **[invoiceIds], not a split.** The on-screen FIFO preview is a
  /// courtesy; the server re-runs the allocation against live balances and
  /// returns the authoritative one. Sending a client-computed split would be
  /// asking the server to trust arithmetic done against a balance that may
  /// already be stale — which, offline, it almost certainly is.
  ///
  /// If the selection no longer covers the amount (another rep collected
  /// against the same invoice first), the server refuses with a 422 carrying
  /// "Selected invoices cover only Rs X…". Let that surface.
  Future<Collection> addCollection({
    required List<String> invoiceIds,
    required CollectionParty party,
    required double amount,
    required DateTime receivedDate,
    required PaymentMode paymentMode,
    String? bankName,
    String? chequeNumber,
    DateTime? chequeDate,
    ChequeStatus? chequeStatus,
    String description = '',
    List<String> imagePaths = const <String>[],
  }) async {
    final link = ref.keepAlive();
    try {
      // `id` / `collectionNo` / `allocations` / `createdAt` are all
      // server-owned. Allocations in particular stay empty here — the client
      // never invents a split.
      final draft = Collection(
        id: '',
        allocations: const <CollectionAllocation>[],
        party: party,
        amount: amount,
        receivedDate: receivedDate,
        paymentMode: paymentMode,
        bankName: bankName,
        chequeNumber: chequeNumber,
        chequeDate: chequeDate,
        chequeStatus: chequeStatus,
        description: description,
        imagePaths: imagePaths,
        createdAt: DateTime.now(),
      );
      final created = await ref
          .read(collectionRepositoryProvider)
          .addCollection(draft, invoiceIds: invoiceIds);
      ref.read(collectionListProvider.notifier).prependLocal(created);
      return created;
    } on PartialImageUploadException catch (e) {
      ref.read(collectionListProvider.notifier).prependLocal(e.collection);
      rethrow;
    } finally {
      link.close();
    }
  }

  /// Save edits to a draft.
  ///
  /// The invoice selection is resent so the server can re-derive the split —
  /// it releases this receipt's own allocations first (that's what
  /// `excludeCollectionId` on the outstanding read mirrors), then re-runs FIFO
  /// over the new amount.
  Future<Collection> updateCollection(
    Collection collection, {
    required List<String> invoiceIds,
  }) async {
    final link = ref.keepAlive();
    try {
      return await ref
          .read(collectionRepositoryProvider)
          .updateCollection(collection, invoiceIds: invoiceIds);
    } finally {
      link.close();
    }
  }

  /// Delete a draft. A posted receipt must be cancelled instead — that writes a
  /// reversal voucher and restores the invoices' outstanding balances.
  Future<void> deleteCollection(String id) async {
    final link = ref.keepAlive();
    try {
      await ref.read(collectionRepositoryProvider).deleteCollection(id);
      ref.read(collectionListProvider.notifier).removeLocal(id);
    } finally {
      link.close();
    }
  }

  /// Advance a cheque through its clearing lifecycle.
  ///
  /// On a posted receipt this moves real money: clearing writes a contra
  /// voucher, and **bouncing writes a reversal that cancels the receipt and
  /// restores the invoices' outstanding balances** — so an invoice this
  /// receipt settled becomes collectible again.
  Future<Collection> updateChequeStatus({
    required String id,
    required ChequeStatus status,
  }) async {
    final link = ref.keepAlive();
    try {
      return await ref
          .read(collectionRepositoryProvider)
          .updateChequeStatus(id: id, status: status);
    } finally {
      link.close();
    }
  }
}
