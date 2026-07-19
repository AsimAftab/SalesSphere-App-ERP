import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/features/parties/data/mappers/party_row_mapper.dart';
import 'package:sales_sphere_erp/features/parties/data/repositories/parties_repository_impl.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/domain/party_credit.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`. The impl import above stays because this
// file actually uses the provider in its own watch calls.
export 'package:sales_sphere_erp/features/parties/data/repositories/parties_repository_impl.dart'
    show partiesRepositoryProvider;

part 'parties_providers.g.dart';

/// Page size for the live `GET /customers` integration. Matches the
/// `?limit=20` the user asked for.
const int _kPartiesPageSize = 20;

/// Session-scoped pagination state. Drift owns the row content; this
/// notifier owns the order + cursor + load-more / search state.
class PartiesListState {
  const PartiesListState({
    this.loadedIds = const <String>[],
    this.nextCursor,
    this.searchQuery = '',
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<String> loadedIds;
  final String? nextCursor;
  final String searchQuery;
  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;

  PartiesListState copyWith({
    List<String>? loadedIds,
    String? nextCursor,
    bool clearNextCursor = false,
    String? searchQuery,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return PartiesListState(
      loadedIds: loadedIds ?? this.loadedIds,
      nextCursor:
          clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

/// Pagination + search controller for the parties list. The UI watches
/// [partiesListVisibleProvider] for the rendered rows; this notifier just
/// orchestrates which IDs are visible and what the next page's cursor is.
@Riverpod(keepAlive: true)
class PartiesList extends _$PartiesList {
  @override
  Future<PartiesListState> build() async {
    final page = await ref
        .read(partiesRepositoryProvider)
        .getPartiesPage(limit: _kPartiesPageSize);
    return PartiesListState(
      loadedIds: page.items.map((p) => p.id).toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }

  /// Apply a new search term. Resets the cursor and refetches page 1.
  Future<void> setSearch(String query) async {
    final trimmed = query.trim();
    final current = state.value;
    if (current != null && current.searchQuery == trimmed) return;
    state = const AsyncValue<PartiesListState>.loading();
    try {
      final page = await ref.read(partiesRepositoryProvider).getPartiesPage(
            limit: _kPartiesPageSize,
            search: trimmed.isEmpty ? null : trimmed,
          );
      state = AsyncValue<PartiesListState>.data(
        PartiesListState(
          loadedIds: page.items.map((p) => p.id).toList(growable: false),
          nextCursor: page.nextCursor,
          searchQuery: trimmed,
        ),
      );
    } catch (e, st) {
      state = AsyncValue<PartiesListState>.error(e, st);
    }
  }

  /// Append the next page. No-op when nothing left to fetch or already
  /// loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.isLoadingMore) return;
    state = AsyncValue<PartiesListState>.data(
      s.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final page = await ref.read(partiesRepositoryProvider).getPartiesPage(
            limit: _kPartiesPageSize,
            cursor: s.nextCursor,
            search: s.searchQuery.isEmpty ? null : s.searchQuery,
          );
      state = AsyncValue<PartiesListState>.data(
        s.copyWith(
          loadedIds: <String>[
            ...s.loadedIds,
            ...page.items.map((p) => p.id),
          ],
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      state = AsyncValue<PartiesListState>.data(
        s.copyWith(isLoadingMore: false, loadMoreError: e),
      );
    }
  }

  /// Insert [id] at the head of `loadedIds` if it isn't already present.
  /// Called by the controller after a successful add so the optimistic
  /// row appears immediately, regardless of where the server's
  /// `name asc` ordering would place it.
  void prependLocal(String id) {
    final current = state.value ?? const PartiesListState();
    if (current.loadedIds.contains(id)) return;
    state = AsyncValue<PartiesListState>.data(
      current.copyWith(
        loadedIds: <String>[id, ...current.loadedIds],
      ),
    );
  }

  /// Atomically swap [localId] for [serverId] in `loadedIds`. Called by
  /// the sync handler's onSuccess after drift has been reconciled so the
  /// rendered row keeps its position when the server-issued id lands.
  /// No-op when the local id isn't currently visible.
  void replaceLocalId(String localId, String serverId) {
    final current = state.value;
    if (current == null) return;
    final idx = current.loadedIds.indexOf(localId);
    if (idx == -1) return;
    final next = <String>[...current.loadedIds];
    next[idx] = serverId;
    state = AsyncValue<PartiesListState>.data(
      current.copyWith(loadedIds: next),
    );
  }

  /// Pull-to-refresh: re-fetch page 1 keeping the current search term.
  Future<void> refresh() async {
    final query = state.value?.searchQuery ?? '';
    state = const AsyncValue<PartiesListState>.loading();
    try {
      final page = await ref.read(partiesRepositoryProvider).getPartiesPage(
            limit: _kPartiesPageSize,
            search: query.isEmpty ? null : query,
          );
      state = AsyncValue<PartiesListState>.data(
        PartiesListState(
          loadedIds: page.items.map((p) => p.id).toList(growable: false),
          nextCursor: page.nextCursor,
          searchQuery: query,
        ),
      );
    } catch (e, st) {
      state = AsyncValue<PartiesListState>.error(e, st);
    }
  }
}

/// Drift-backed list of the currently-visible parties. Re-emits whenever
/// drift rows or the notifier's `loadedIds` change.
@riverpod
Stream<List<Party>> partiesListVisible(Ref ref) {
  final ids = ref.watch(partiesListProvider).value?.loadedIds ??
      const <String>[];
  final dao = ref.watch(partiesDaoProvider);
  return dao
      .watchByIds(ids)
      .map((rows) => rows.map(partyRowToDomain).toList(growable: false));
}

/// Detail-page lookup. Hits drift first (instant); falls back to the API
/// for cold-start deep-links.
@riverpod
Future<Party?> partyById(Ref ref, String id) async {
  return ref.read(partiesRepositoryProvider).getPartyById(id);
}

/// Catalogue of party types used by the picker. Backed by a mock list in
/// the API today — swap to a real fetch when the backend ships it.
@riverpod
Future<List<String>> partyTypes(Ref ref) async {
  return ref.watch(partiesRepositoryProvider).getPartyTypes();
}

/// Live credit-exposure snapshot for the detail page. Network-only by
/// design (see `PartiesRepository.getPartyCredit`) — the page falls back
/// to the drift-cached `Party.creditLimitAmount` when this errors
/// (offline, or the backend predates the endpoint).
@riverpod
Future<PartyCredit> partyCredit(Ref ref, String id) async {
  return ref.watch(partiesRepositoryProvider).getPartyCredit(id);
}
