// `limit: _kNotesPageSize` is intentional even though it matches the
// repo's default — the constant is the single source of truth for the
// notes page size and naming it at every callsite documents that
// intent for readers (and matches how `parties_providers.dart` does
// it). Disable the redundant-argument lint on a per-file basis to
// keep the explicit `limit:` arguments without per-line ignores.
// ignore_for_file: avoid_redundant_argument_values

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/notes/data/notes_api.dart';
import 'package:sales_sphere_erp/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:sales_sphere_erp/features/notes/domain/note.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';
import 'package:sales_sphere_erp/features/prospects/presentation/providers/prospects_providers.dart';
import 'package:sales_sphere_erp/features/sites/presentation/providers/sites_providers.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`. The impl import above stays because this
// file actually uses the provider in its own watch calls.
export 'package:sales_sphere_erp/features/notes/data/notes_api.dart'
    show NotesRelatedTo;
export 'package:sales_sphere_erp/features/notes/data/repositories/notes_repository_impl.dart'
    show notesRepositoryProvider;

part 'notes_providers.g.dart';

/// Page size for the live `GET /notes` integration. Mirrors the
/// `?limit=10` requested by the list screen.
const int _kNotesPageSize = 10;

/// Session-scoped pagination + filter state for the notes list.
class NotesListState {
  const NotesListState({
    this.items = const <Note>[],
    this.nextCursor,
    this.relatedTo,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<Note> items;
  final String? nextCursor;

  /// Server-side `relatedTo` filter (`customer | prospect | site`).
  /// `null` means "no filter" — show notes for every link type.
  final NotesRelatedTo? relatedTo;

  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;

  NotesListState copyWith({
    List<Note>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    NotesRelatedTo? relatedTo,
    bool clearRelatedTo = false,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return NotesListState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      relatedTo: clearRelatedTo ? null : (relatedTo ?? this.relatedTo),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

/// Pagination + filter controller for the notes list. The UI watches
/// this provider directly; new pages are appended to `items`.
@Riverpod(keepAlive: true)
class NotesList extends _$NotesList {
  @override
  Future<NotesListState> build() async {
    final page = await ref
        .read(notesRepositoryProvider)
        .getNotesPage(limit: _kNotesPageSize);
    return NotesListState(items: page.items, nextCursor: page.nextCursor);
  }

  /// Apply (or clear) the `relatedTo` filter. Resets the cursor and
  /// refetches page 1.
  Future<void> setRelatedTo(NotesRelatedTo? next) async {
    final current = state.value;
    if (current != null && current.relatedTo == next) return;
    state = const AsyncValue<NotesListState>.loading();
    try {
      final page = await ref
          .read(notesRepositoryProvider)
          .getNotesPage(limit: _kNotesPageSize, relatedTo: next);
      state = AsyncValue<NotesListState>.data(
        NotesListState(
          items: page.items,
          nextCursor: page.nextCursor,
          relatedTo: next,
        ),
      );
    } on Object catch (e, st) {
      state = AsyncValue<NotesListState>.error(e, st);
    }
  }

  /// Append the next page. No-op when nothing left to fetch or
  /// already loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.isLoadingMore) return;
    state = AsyncValue<NotesListState>.data(
      s.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final page = await ref.read(notesRepositoryProvider).getNotesPage(
        limit: _kNotesPageSize,
        cursor: s.nextCursor,
        relatedTo: s.relatedTo,
      );
      state = AsyncValue<NotesListState>.data(
        s.copyWith(
          items: <Note>[...s.items, ...page.items],
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          isLoadingMore: false,
        ),
      );
    } on Object catch (e) {
      state = AsyncValue<NotesListState>.data(
        s.copyWith(isLoadingMore: false, loadMoreError: e),
      );
    }
  }

  /// Pull-to-refresh: re-fetch page 1 keeping the current filter.
  Future<void> refresh() async {
    final filter = state.value?.relatedTo;
    state = const AsyncValue<NotesListState>.loading();
    try {
      final page = await ref
          .read(notesRepositoryProvider)
          .getNotesPage(limit: _kNotesPageSize, relatedTo: filter);
      state = AsyncValue<NotesListState>.data(
        NotesListState(
          items: page.items,
          nextCursor: page.nextCursor,
          relatedTo: filter,
        ),
      );
    } on Object catch (e, st) {
      state = AsyncValue<NotesListState>.error(e, st);
    }
  }

  /// Insert [note] at the head of `items` if the row isn't already
  /// present. Called by the controller after a successful add so the
  /// optimistic row appears immediately.
  void prependLocal(Note note) {
    final current = state.value ?? const NotesListState();
    if (current.items.any((n) => n.id == note.id)) return;
    state = AsyncValue<NotesListState>.data(
      current.copyWith(items: <Note>[note, ...current.items]),
    );
  }

  /// Replace the row matching [note].id with [note]. No-op when the
  /// note isn't currently visible. Called after a successful update.
  void replaceLocal(Note note) {
    final current = state.value;
    if (current == null) return;
    final idx = current.items.indexWhere((n) => n.id == note.id);
    if (idx == -1) return;
    final next = <Note>[...current.items];
    next[idx] = note;
    state = AsyncValue<NotesListState>.data(current.copyWith(items: next));
  }
}

/// Convenience provider for screens that just need the current list
/// of loaded notes (without pagination state). Derives from
/// [notesListProvider] so both share the same fetch.
@riverpod
Future<List<Note>> notesListItems(Ref ref) async {
  final state = await ref.watch(notesListProvider.future);
  return state.items;
}

/// Resolves a single note by id from the currently-loaded items.
/// Returns `null` if the note hasn't been fetched yet (deep-link
/// callers should pass the note via `extra` to avoid this).
@riverpod
Future<Note?> noteById(Ref ref, String id) async {
  final notes = await ref.watch(notesListItemsProvider.future);
  for (final note in notes) {
    if (note.id == id) return note;
  }
  return null;
}

/// Resolves the linked entity's display name for a note. The wire
/// shape only carries `customerId | prospectId | siteId`, not the
/// linked entity's name, so the UI calls this provider per row to
/// pull the name from the relevant by-id provider in
/// parties / prospects / sites. Falls back to a generic label
/// (`"Customer"` / `"Prospect"` / `"Site"`) while the lookup is in
/// flight or if the entity can't be found — same string the
/// repository's `_fallbackLinkLabel` returns, so it composes cleanly
/// during the loading window.
@riverpod
Future<String> noteLinkDisplayName(
  Ref ref,
  NoteLinkType type,
  String linkId,
) async {
  switch (type) {
    case NoteLinkType.party:
      final party = await ref.watch(partyByIdProvider(linkId).future);
      return party?.name ?? 'Customer';
    case NoteLinkType.prospect:
      final prospect = await ref.watch(prospectByIdProvider(linkId).future);
      return prospect?.name ?? 'Prospect';
    case NoteLinkType.site:
      final site = await ref.watch(siteByIdProvider(linkId).future);
      return site?.name ?? 'Site';
  }
}
