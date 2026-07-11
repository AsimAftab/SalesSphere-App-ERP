import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/features/collection/data/repositories/collection_repository_impl.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';

// Re-export the repository provider so controllers and tests depend on the
// contract surface without importing from `data/`.
export 'package:sales_sphere_erp/features/collection/data/repositories/collection_repository_impl.dart'
    show collectionRepositoryProvider;

part 'collection_providers.g.dart';

const int _kCollectionsPageSize = 15;

/// Parties offered in the "Select party" bottom sheet, mapped from the live
/// customers list to the slim shape the picker already consumes.
///
/// Watching [partiesListVisibleProvider] auto-loads the first page of
/// customers on demand — the same source the notes and expense-claim pickers
/// use. (The module used to ship its own hardcoded fixtures because it was
/// built before the parties API landed.)
@riverpod
List<CollectionParty> collectionParties(Ref ref) {
  final parties = ref.watch(partiesListVisibleProvider).value ?? const <Party>[];
  return parties
      .map(
        (p) => CollectionParty(
          id: p.id,
          name: p.name,
          address: p.address,
          ownerName: p.ownerName,
        ),
      )
      .toList(growable: false);
}

/// Bank catalogue for the cheque / bank-transfer picker.
///
/// A **suggestion list, not an enum** — `bankName` is free text on the wire,
/// and the picker keeps its "add a different bank" escape hatch.
@riverpod
Future<List<String>> collectionBankNames(Ref ref) =>
    ref.watch(collectionRepositoryProvider).getBankNames();

/// Session-scoped pagination + filter state.
///
/// Drift owns the row *content*; this notifier owns the *order*, the cursor
/// and the active filters. That split is what lets a sync-handler write
/// re-render the list without the page knowing sync happened.
///
/// Every filter is applied **server-side** — the mock used to load everything
/// and filter in Dart, which quietly broke as soon as the list outgrew one
/// page.
class CollectionListState {
  const CollectionListState({
    this.loadedIds = const <String>[],
    this.nextCursor,
    this.searchQuery = '',
    this.paymentModeFilter,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<String> loadedIds;
  final String? nextCursor;
  final String searchQuery;
  final PaymentMode? paymentModeFilter;
  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;

  CollectionListState copyWith({
    List<String>? loadedIds,
    String? nextCursor,
    bool clearNextCursor = false,
    String? searchQuery,
    PaymentMode? paymentModeFilter,
    bool clearPaymentModeFilter = false,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return CollectionListState(
      loadedIds: loadedIds ?? this.loadedIds,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      searchQuery: searchQuery ?? this.searchQuery,
      paymentModeFilter: clearPaymentModeFilter
          ? null
          : (paymentModeFilter ?? this.paymentModeFilter),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : (loadMoreError ?? this.loadMoreError),
    );
  }
}

@Riverpod(keepAlive: true)
class CollectionList extends _$CollectionList {
  @override
  Future<CollectionListState> build() async {
    final page = await ref
        .read(collectionRepositoryProvider)
        .getCollectionsPage(limit: _kCollectionsPageSize);
    return CollectionListState(
      loadedIds: page.items.map((c) => c.id).toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }

  Future<void> setPaymentModeFilter(PaymentMode? mode) async {
    final current = state.value;
    if (current != null && current.paymentModeFilter == mode) return;
    final search = current?.searchQuery ?? '';
    state = const AsyncValue<CollectionListState>.loading();
    await _fetchPageOne(paymentMode: mode, search: search);
  }

  Future<void> setSearch(String query) async {
    final trimmed = query.trim();
    final current = state.value;
    if (current != null && current.searchQuery == trimmed) return;
    final mode = current?.paymentModeFilter;
    state = const AsyncValue<CollectionListState>.loading();
    await _fetchPageOne(paymentMode: mode, search: trimmed);
  }

  Future<void> refresh() async {
    final current = state.value;
    await _fetchPageOne(
      paymentMode: current?.paymentModeFilter,
      search: current?.searchQuery ?? '',
    );
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.isLoadingMore) return;
    state = AsyncValue<CollectionListState>.data(
      s.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final page = await ref
          .read(collectionRepositoryProvider)
          .getCollectionsPage(
            limit: _kCollectionsPageSize,
            cursor: s.nextCursor,
            search: s.searchQuery.isEmpty ? null : s.searchQuery,
            paymentMode: s.paymentModeFilter,
          );
      state = AsyncValue<CollectionListState>.data(
        s.copyWith(
          loadedIds: <String>[
            ...s.loadedIds,
            ...page.items.map((c) => c.id),
          ],
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          isLoadingMore: false,
        ),
      );
    } on Object catch (e) {
      state = AsyncValue<CollectionListState>.data(
        s.copyWith(isLoadingMore: false, loadMoreError: e),
      );
    }
  }

  /// Insert [id] at the head after a successful add, so an optimistic row
  /// appears immediately regardless of where the server's ordering would put
  /// it. Skipped when the active payment-mode filter wouldn't include it.
  void prependLocal(Collection collection) {
    final current = state.value ?? const CollectionListState();
    if (current.paymentModeFilter != null &&
        current.paymentModeFilter != collection.paymentMode) {
      return;
    }
    if (current.loadedIds.contains(collection.id)) return;
    state = AsyncValue<CollectionListState>.data(
      current.copyWith(
        loadedIds: <String>[collection.id, ...current.loadedIds],
      ),
    );
  }

  /// Drop a row after a successful delete.
  void removeLocal(String id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue<CollectionListState>.data(
      current.copyWith(
        loadedIds: current.loadedIds.where((x) => x != id).toList(
          growable: false,
        ),
      ),
    );
  }

  /// Swap a `local_<uuid>` id for the server-issued one once the outbox drains.
  /// Called by the sync handler *after* drift has been reconciled, so the
  /// rendered row keeps its position instead of blinking out and back.
  void replaceLocalId(String localId, String serverId) {
    final current = state.value;
    if (current == null) return;
    final idx = current.loadedIds.indexOf(localId);
    if (idx == -1) return;
    final next = <String>[...current.loadedIds];
    next[idx] = serverId;
    state = AsyncValue<CollectionListState>.data(
      current.copyWith(loadedIds: next),
    );
  }

  Future<void> _fetchPageOne({
    required PaymentMode? paymentMode,
    required String search,
  }) async {
    try {
      final page = await ref
          .read(collectionRepositoryProvider)
          .getCollectionsPage(
            limit: _kCollectionsPageSize,
            paymentMode: paymentMode,
            search: search.isEmpty ? null : search,
          );
      state = AsyncValue<CollectionListState>.data(
        CollectionListState(
          loadedIds: page.items.map((c) => c.id).toList(growable: false),
          nextCursor: page.nextCursor,
          searchQuery: search,
          paymentModeFilter: paymentMode,
        ),
      );
    } on Object catch (e, st) {
      state = AsyncValue<CollectionListState>.error(e, st);
    }
  }
}

/// Drift-backed view of the currently-loaded collections. Re-emits whenever
/// the rows change or the notifier's `loadedIds` do — which is how a
/// background sync silently upgrades a pending row to a synced one.
@riverpod
Stream<List<Collection>> collectionsListVisible(Ref ref) {
  final ids =
      ref.watch(collectionListProvider).value?.loadedIds ?? const <String>[];
  final dao = ref.watch(collectionsDaoProvider);
  return dao.watchByIds(ids).map(
    (rows) => rows.map(collectionRowToDomain).toList(growable: false),
  );
}

/// Detail-page lookup: hydrate, then watch.
///
/// Drift answers instantly for a row already in the list. A cold-start deep
/// link won't be cached, so we fetch it once and then hand over to the drift
/// stream — which means the page also live-updates when a cheque-status change
/// or a background sync rewrites the row, with no manual refresh.
///
/// A `local_<uuid>` row only ever exists on this device, so there's nothing to
/// fetch for it.
@riverpod
Stream<Collection?> collectionById(Ref ref, String id) async* {
  final dao = ref.watch(collectionsDaoProvider);
  final cached = await dao.findById(id);
  if (cached == null && !id.startsWith('local_')) {
    await ref.read(collectionRepositoryProvider).getCollectionById(id);
  }
  yield* dao.watchById(id).map(
    (row) => row == null ? null : collectionRowToDomain(row),
  );
}
