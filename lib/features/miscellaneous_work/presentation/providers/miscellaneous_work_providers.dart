// `limit: _kMiscellaneousWorkPageSize` is intentional even though it
// matches the repo's default — the constant is the single source of
// truth for the page size and naming it at every callsite documents
// that intent for readers (and matches how `notes_providers.dart`
// does it). Disable the redundant-argument lint on a per-file basis
// to keep the explicit `limit:` arguments without per-line ignores.
// ignore_for_file: avoid_redundant_argument_values

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/miscellaneous_work/data/repositories/miscellaneous_work_repository_impl.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`. The impl import above stays because this
// file actually uses the provider in its own watch calls.
export 'package:sales_sphere_erp/features/miscellaneous_work/data/repositories/miscellaneous_work_repository_impl.dart'
    show miscellaneousWorkRepositoryProvider;

part 'miscellaneous_work_providers.g.dart';

/// Page size for the live `GET /miscellaneous-work` integration.
/// Mirrors the `?limit=10` requested by the list screen.
const int _kMiscellaneousWorkPageSize = 10;

/// Session-scoped pagination state for the miscellaneous-work list.
class MiscellaneousWorkListState {
  const MiscellaneousWorkListState({
    this.items = const <MiscellaneousWork>[],
    this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<MiscellaneousWork> items;
  final String? nextCursor;

  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;

  MiscellaneousWorkListState copyWith({
    List<MiscellaneousWork>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return MiscellaneousWorkListState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

/// Pagination controller for the miscellaneous-work list. The UI
/// watches this provider directly; new pages are appended to `items`.
@Riverpod(keepAlive: true)
class MiscellaneousWorkList extends _$MiscellaneousWorkList {
  @override
  Future<MiscellaneousWorkListState> build() async {
    final page = await ref
        .read(miscellaneousWorkRepositoryProvider)
        .getPage(limit: _kMiscellaneousWorkPageSize);
    return MiscellaneousWorkListState(
      items: page.items,
      nextCursor: page.nextCursor,
    );
  }

  /// Append the next page. No-op when nothing left to fetch or
  /// already loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.isLoadingMore) return;
    state = AsyncValue<MiscellaneousWorkListState>.data(
      s.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final page = await ref
          .read(miscellaneousWorkRepositoryProvider)
          .getPage(limit: _kMiscellaneousWorkPageSize, cursor: s.nextCursor);
      state = AsyncValue<MiscellaneousWorkListState>.data(
        s.copyWith(
          items: <MiscellaneousWork>[...s.items, ...page.items],
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          isLoadingMore: false,
        ),
      );
    } on Object catch (e) {
      state = AsyncValue<MiscellaneousWorkListState>.data(
        s.copyWith(isLoadingMore: false, loadMoreError: e),
      );
    }
  }

  /// Pull-to-refresh: re-fetch page 1.
  Future<void> refresh() async {
    state = const AsyncValue<MiscellaneousWorkListState>.loading();
    try {
      final page = await ref
          .read(miscellaneousWorkRepositoryProvider)
          .getPage(limit: _kMiscellaneousWorkPageSize);
      state = AsyncValue<MiscellaneousWorkListState>.data(
        MiscellaneousWorkListState(
          items: page.items,
          nextCursor: page.nextCursor,
        ),
      );
    } on Object catch (e, st) {
      state = AsyncValue<MiscellaneousWorkListState>.error(e, st);
    }
  }

  /// Insert [work] at the head of `items` if the row isn't already
  /// present. Called by the controller after a successful add so the
  /// optimistic row appears immediately.
  void prependLocal(MiscellaneousWork work) {
    final current = state.value ?? const MiscellaneousWorkListState();
    if (current.items.any((w) => w.id == work.id)) return;
    state = AsyncValue<MiscellaneousWorkListState>.data(
      current.copyWith(items: <MiscellaneousWork>[work, ...current.items]),
    );
  }

  /// Replace the row matching [work].id with [work]. No-op when the
  /// work isn't currently visible. Called after a successful update.
  void replaceLocal(MiscellaneousWork work) {
    final current = state.value;
    if (current == null) return;
    final idx = current.items.indexWhere((w) => w.id == work.id);
    if (idx == -1) return;
    final next = <MiscellaneousWork>[...current.items];
    next[idx] = work;
    state = AsyncValue<MiscellaneousWorkListState>.data(
      current.copyWith(items: next),
    );
  }
}

/// Convenience provider for screens that just need the current list
/// of loaded rows (without pagination state). Derives from
/// [miscellaneousWorkListProvider] so both share the same fetch.
@riverpod
Future<List<MiscellaneousWork>> miscellaneousWorkListItems(Ref ref) async {
  final state = await ref.watch(miscellaneousWorkListProvider.future);
  return state.items;
}

/// Resolves a single work item by id from the currently-loaded items.
/// Returns `null` if it hasn't been fetched yet (deep-link callers
/// should pass the row via `extra` to avoid this).
@riverpod
Future<MiscellaneousWork?> miscellaneousWorkById(Ref ref, String id) async {
  final items = await ref.watch(miscellaneousWorkListItemsProvider.future);
  for (final w in items) {
    if (w.id == id) return w;
  }
  return null;
}
