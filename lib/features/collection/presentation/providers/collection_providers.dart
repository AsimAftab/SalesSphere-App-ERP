import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/collection/data/collection_mock_data.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';

part 'collection_providers.g.dart';

/// Parties offered in the "Select party" bottom sheet. Synchronous — no
/// API/drift yet (mock-only). Swap for a repository read when the
/// collection feature is wired to the backend.
@riverpod
List<CollectionParty> collectionParties(Ref ref) => kMockCollectionParties;

/// Bank names offered in the cheque / bank-transfer picker. Synchronous
/// mock; stands in for v1's `/collections/utils/bank-names` endpoint.
@riverpod
List<String> collectionBankNames(Ref ref) => kMockBankNames;

/// In-memory list of collections, seeded from the mock corpus. The list
/// screen watches this directly; the controller prepends new rows after
/// a successful add so the optimistic row appears at the top.
///
/// Async so the list screen has a real loading window to paint a
/// skeleton against. The short delay stands in for a network fetch —
/// swap `build` for a `repo.getCollections()` call when a backend lands.
@Riverpod(keepAlive: true)
class CollectionList extends _$CollectionList {
  @override
  Future<List<Collection>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List<Collection>.from(kMockCollectionList);
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
      ref.watch(collectionListProvider).value ?? const <Collection>[];
  for (final collection in collections) {
    if (collection.id == id) return collection;
  }
  return null;
}
