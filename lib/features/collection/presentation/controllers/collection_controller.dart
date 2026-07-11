import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection/domain/repositories/collection_repository.dart';
// `collection_providers.dart` re-exports `collectionRepositoryProvider` so the
// controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/collection/presentation/providers/collection_providers.dart';

part 'collection_controller.g.dart';

/// Routes collection write actions from the UI through the repository. Reads
/// stay on `collectionsListVisibleProvider` / `collectionByIdProvider`.
///
/// The list is patched in place (`prependLocal` / `removeLocal`) rather than
/// invalidated — that keeps the new row visible without a refetch and without
/// throwing away the user's scroll position. Edits need no patch at all: row
/// *content* streams from drift, which the repository has already written.
///
/// Each write opens a `ref.keepAlive()` link for the duration of its in-flight
/// await and closes it in `finally`, keeping the notifier valid through the
/// post-await state patch without permanently pinning a write-only controller
/// in memory.
@riverpod
class CollectionController extends _$CollectionController {
  @override
  void build() {}

  /// Record a receipt. The server lands it as a DRAFT — nothing reaches the
  /// ledger until an accountant posts it.
  ///
  /// **Offline this still succeeds.** The repository caches the row and queues
  /// the create against a UUID replay key; the returned collection carries
  /// `syncPending`. Callers must not treat that as a failure — the money is
  /// recorded, and the receipt syncs when the device reconnects.
  Future<Collection> addCollection({
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
      // `id` / `collectionNo` / `createdAt` are server-owned. The placeholders
      // here are overwritten by the created row (or by a `local_<uuid>` id on
      // the offline path).
      final draft = Collection(
        id: '',
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
          .addCollection(draft);
      ref.read(collectionListProvider.notifier).prependLocal(created);
      return created;
    } on PartialImageUploadException catch (e) {
      // The receipt saved; only a proof photo didn't. Show the row anyway and
      // let the page surface the upload failure.
      ref.read(collectionListProvider.notifier).prependLocal(e.collection);
      rethrow;
    } finally {
      link.close();
    }
  }

  /// Save edits to a draft. The server 409s once the receipt is posted or
  /// cancelled, and the party is immutable.
  Future<Collection> updateCollection(Collection collection) async {
    final link = ref.keepAlive();
    try {
      return await ref
          .read(collectionRepositoryProvider)
          .updateCollection(collection);
    } finally {
      link.close();
    }
  }

  /// Delete a draft. A posted receipt cannot be deleted — it must be
  /// cancelled, which writes a reversal voucher. The server enforces that.
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
  /// voucher (cheque-in-hand → bank), and bouncing writes a reversal that
  /// cancels the receipt and restores the customer's outstanding balance.
  /// Illegal moves are refused server-side (409) — `cleared` and `bounced`
  /// are terminal.
  ///
  /// No list patch: the new status streams back out of drift.
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
