import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/collection/data/collection_mock_data.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_invoice.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/orders/domain/order.dart';
import 'package:sales_sphere_erp/features/orders/presentation/providers/order_providers.dart';

part 'collection_providers.g.dart';

/// Parties offered in the "Select party" bottom sheet. Synchronous — no
/// API/drift yet (mock-only). Swap for a repository read when the
/// collection feature is wired to the backend.
@riverpod
List<CollectionParty> collectionParties(Ref ref) => kMockCollectionParties;

/// Bank names offered in the cheque / bank-transfer picker. Synchronous
/// mock; stands in for v1's `/collections/utils/bank-names` endpoint.
@riverpod
List<String> bankNames(Ref ref) => kMockBankNames;

/// Posted invoices a collection can be booked against, projected from
/// the orders corpus. Only a delivery-`completed` order (`kind: order`)
/// is collectible — estimates aren't invoices, and orders still in the
/// delivery pipeline (pending / in-progress / in-transit) or rejected
/// are excluded. Most recent first.
///
/// Synchronous off the orders history's current value — watching this
/// provider warms `orderHistoryProvider`, so the list fills in once that
/// resolves (and stays warm, as it's keepAlive). When a backend lands,
/// swap for a real "outstanding invoices" read filtered server-side.
@riverpod
List<CollectionInvoice> collectionInvoices(Ref ref) {
  final orders = ref.watch(orderHistoryProvider).value ?? const <Order>[];
  return <CollectionInvoice>[
    for (final o in orders)
      if (o.kind == OrderKind.order && o.status == OrderStatus.completed)
        CollectionInvoice(
          id: o.id,
          number: o.number,
          amount: o.grandTotal,
          partyId: o.party?.id,
          partyName: o.party?.name ?? '',
        ),
  ];
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
class CollectionsList extends _$CollectionsList {
  @override
  Future<List<Collection>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List<Collection>.from(kMockCollections);
  }

  /// Insert [collection] at the head of the list. Called by the
  /// controller after a successful add.
  void prependLocal(Collection collection) {
    final current = state.value ?? const <Collection>[];
    if (current.any((c) => c.id == collection.id)) return;
    state = AsyncValue<List<Collection>>.data(
      <Collection>[collection, ...current],
    );
  }

  /// Replace the row matching [collection].id. No-op when the row isn't
  /// present. Called by the controller after a successful edit.
  void replaceLocal(Collection collection) {
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((c) => c.id == collection.id);
    if (idx == -1) return;
    final next = <Collection>[...current];
    next[idx] = collection;
    state = AsyncValue<List<Collection>>.data(next);
  }

  /// Pull-to-refresh. Mock-only: there's no backend to re-fetch from, so
  /// this simulates a network round-trip and re-emits the current list
  /// (locally-added / edited rows are preserved). When a backend lands
  /// this becomes a real `repo.getCollections()` call.
  Future<void> refresh() async {
    final current = state.value ?? const <Collection>[];
    await Future<void>.delayed(const Duration(milliseconds: 600));
    state = AsyncValue<List<Collection>>.data(<Collection>[...current]);
  }
}

/// Resolves a single collection by id from the loaded list. Returns
/// `null` when the list hasn't resolved yet or the id isn't present
/// (deep-link callers pass the row via `extra` to avoid the former).
@riverpod
Collection? collectionById(Ref ref, String id) {
  final collections =
      ref.watch(collectionsListProvider).value ?? const <Collection>[];
  for (final collection in collections) {
    if (collection.id == id) return collection;
  }
  return null;
}
