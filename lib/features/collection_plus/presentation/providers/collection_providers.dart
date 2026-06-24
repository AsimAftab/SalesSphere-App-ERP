import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/collection_plus/data/collection_mock_data.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_invoice.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/invoice_due.dart';

part 'collection_providers.g.dart';

/// Parties offered in the "Select party" bottom sheet. Synchronous — no
/// API/drift yet (mock-only). Swap for a repository read when the
/// collection feature is wired to the backend.
@riverpod
List<CollectionPlusParty> collectionPlusParties(Ref ref) => kMockCollectionPlusParties;

/// Bank names offered in the cheque / bank-transfer picker. Synchronous
/// mock; stands in for v1's `/collections/utils/bank-names` endpoint.
@riverpod
List<String> bankNames(Ref ref) => kMockBankNames;

/// Posted invoices a collection can be booked against — the outstanding
/// pool the form allocates payments across.
///
/// Collection Plus is still mock-only while orders/catalog moved to the
/// live backend. The backend orders history now carries real server ids
/// that no longer match the mock collections' allocations, so this returns
/// the module's self-contained [kMockCollectionPlusInvoices] corpus
/// instead — keeping invoice ids and parties aligned with
/// [kMockCollectionPlusList]. Swap for a real "outstanding invoices" read
/// when the collection feature is wired to the backend.
@riverpod
List<CollectionPlusInvoice> collectionPlusInvoices(Ref ref) =>
    kMockCollectionPlusInvoices;

/// A party's outstanding invoices, oldest-first — the list the collection
/// form shows once a party is chosen, and the basis for FIFO allocation.
///
/// For each of [partyId]'s posted invoices, sums the allocations already
/// booked against it across every recorded collection, then keeps only
/// those with a positive balance (`amount - paid`, clamped at zero).
/// Sorted by [CollectionPlusInvoice.invoiceDate] ascending so a payment
/// settles the oldest bill first.
///
/// [excludeCollectionId] releases one collection's allocations from the
/// paid totals — passed by the edit flow so a collection is re-balanced
/// against the outstanding as if it didn't exist (its own settled amount
/// becomes available again).
@riverpod
List<InvoiceDue> outstandingInvoicesForParty(
  Ref ref,
  String partyId, {
  String? excludeCollectionId,
}) {
  final invoices = ref
      .watch(collectionPlusInvoicesProvider)
      .where((inv) => inv.partyId == partyId);
  final collections =
      ref.watch(collectionPlusListProvider).value ?? const <CollectionPlus>[];

  // Total already paid against each invoice id, plus the most recent
  // collection date among those payments.
  final paidByInvoice = <String, double>{};
  final lastPaidByInvoice = <String, DateTime>{};
  for (final c in collections) {
    if (excludeCollectionId != null && c.id == excludeCollectionId) continue;
    for (final a in c.allocations) {
      paidByInvoice[a.invoiceId] = (paidByInvoice[a.invoiceId] ?? 0) + a.amount;
      final prev = lastPaidByInvoice[a.invoiceId];
      if (prev == null || c.receivedDate.isAfter(prev)) {
        lastPaidByInvoice[a.invoiceId] = c.receivedDate;
      }
    }
  }

  final dues = <InvoiceDue>[
    for (final inv in invoices)
      if (inv.amount - (paidByInvoice[inv.id] ?? 0) > 0.0001)
        InvoiceDue(
          invoice: inv,
          paid: paidByInvoice[inv.id] ?? 0,
          outstanding: inv.amount - (paidByInvoice[inv.id] ?? 0),
          lastPaidOn: lastPaidByInvoice[inv.id],
        ),
  ]..sort((a, b) => a.invoice.invoiceDate.compareTo(b.invoice.invoiceDate));
  return dues;
}

/// In-memory list of collections, seeded from the mock corpus. The list
/// screen watches this directly; the controller prepends new rows after
/// a successful add so the optimistic row appears at the top.
///
/// Async so the list screen has a real loading window to paint a
/// skeleton against (mirrors `ExpenseClaimsList`). The short delay
/// stands in for a network fetch — swap `build` for a
/// `repo.getCollections()` call when a backend lands.
@Riverpod(keepAlive: true)
class CollectionPlusList extends _$CollectionPlusList {
  @override
  Future<List<CollectionPlus>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List<CollectionPlus>.from(kMockCollectionPlusList);
  }

  /// Insert [collection] at the head of the list. Called by the
  /// controller after a successful add.
  void prependLocal(CollectionPlus collection) {
    final current = state.value ?? const <CollectionPlus>[];
    if (current.any((c) => c.id == collection.id)) return;
    state = AsyncValue<List<CollectionPlus>>.data(
      <CollectionPlus>[collection, ...current],
    );
  }

  /// Replace the row matching [collection].id. No-op when the row isn't
  /// present. Called by the controller after a successful edit.
  void replaceLocal(CollectionPlus collection) {
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((c) => c.id == collection.id);
    if (idx == -1) return;
    final next = <CollectionPlus>[...current];
    next[idx] = collection;
    state = AsyncValue<List<CollectionPlus>>.data(next);
  }

  /// Pull-to-refresh. Mock-only: there's no backend to re-fetch from, so
  /// this simulates a network round-trip and re-emits the current list
  /// (locally-added / edited rows are preserved). When a backend lands
  /// this becomes a real `repo.getCollections()` call.
  Future<void> refresh() async {
    final current = state.value ?? const <CollectionPlus>[];
    await Future<void>.delayed(const Duration(milliseconds: 600));
    state = AsyncValue<List<CollectionPlus>>.data(<CollectionPlus>[...current]);
  }
}

/// Resolves a single collection by id from the loaded list. Returns
/// `null` when the list hasn't resolved yet or the id isn't present
/// (deep-link callers pass the row via `extra` to avoid the former).
@riverpod
CollectionPlus? collectionPlusById(Ref ref, String id) {
  final collections =
      ref.watch(collectionPlusListProvider).value ?? const <CollectionPlus>[];
  for (final collection in collections) {
    if (collection.id == id) return collection;
  }
  return null;
}
