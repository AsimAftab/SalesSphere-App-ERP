import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_party.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';

// Re-export the repository provider so downstream consumers (controllers,
// tests) can depend on the contract surface without importing from `data/`.
export 'package:sales_sphere_erp/features/expenses/data/repositories/expense_repository_impl.dart'
    show expenseRepositoryProvider;

part 'expenses_providers.g.dart';

/// Page size for the live `GET /expense-claims/my-requests` integration.
const int _kExpenseClaimsPageSize = 15;

/// Session-scoped pagination + filter state for the expense-claims list.
class ExpenseClaimsListState {
  const ExpenseClaimsListState({
    this.items = const <ExpenseClaim>[],
    this.nextCursor,
    this.statusFilter,
    this.searchQuery = '',
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<ExpenseClaim> items;
  final String? nextCursor;

  /// Server-side `status` filter (`PENDING | APPROVED | REJECTED`).
  /// `null` means "no filter" — every status.
  final ExpenseClaimStatus? statusFilter;

  /// Server-side `search` term (matches title / category). Empty means no
  /// search.
  final String searchQuery;

  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;

  ExpenseClaimsListState copyWith({
    List<ExpenseClaim>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    ExpenseClaimStatus? statusFilter,
    bool clearStatusFilter = false,
    String? searchQuery,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return ExpenseClaimsListState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

/// Pagination + filter controller for the caller's own expense claims.
/// The UI watches this provider directly; new pages are appended to
/// `items`, and the controller patches it in-place (`prependLocal` /
/// `replaceLocal`) after a successful write so the optimistic row updates
/// without losing scroll position.
@Riverpod(keepAlive: true)
class ExpenseClaimsList extends _$ExpenseClaimsList {
  @override
  Future<ExpenseClaimsListState> build() async {
    final page = await ref
        .read(expenseRepositoryProvider)
        .getClaimsPage(limit: _kExpenseClaimsPageSize);
    return ExpenseClaimsListState(
      items: page.items,
      nextCursor: page.nextCursor,
    );
  }

  /// Apply (or clear) the status filter. Resets the cursor and refetches
  /// page 1, keeping the current search term.
  Future<void> setStatusFilter(ExpenseClaimStatus? status) async {
    final current = state.value;
    if (current != null && current.statusFilter == status) return;
    final search = current?.searchQuery ?? '';
    state = const AsyncValue<ExpenseClaimsListState>.loading();
    await _fetchPageOne(status: status, search: search);
  }

  /// Apply a new search term. Resets the cursor and refetches page 1,
  /// keeping the current status filter.
  Future<void> setSearch(String query) async {
    final trimmed = query.trim();
    final current = state.value;
    if (current != null && current.searchQuery == trimmed) return;
    final status = current?.statusFilter;
    state = const AsyncValue<ExpenseClaimsListState>.loading();
    await _fetchPageOne(status: status, search: trimmed);
  }

  /// Append the next page. No-op when nothing left to fetch or already
  /// loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.isLoadingMore) return;
    state = AsyncValue<ExpenseClaimsListState>.data(
      s.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final page = await ref.read(expenseRepositoryProvider).getClaimsPage(
        limit: _kExpenseClaimsPageSize,
        cursor: s.nextCursor,
        status: s.statusFilter,
        search: s.searchQuery.isEmpty ? null : s.searchQuery,
      );
      state = AsyncValue<ExpenseClaimsListState>.data(
        s.copyWith(
          items: <ExpenseClaim>[...s.items, ...page.items],
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          isLoadingMore: false,
        ),
      );
    } on Object catch (e) {
      state = AsyncValue<ExpenseClaimsListState>.data(
        s.copyWith(isLoadingMore: false, loadMoreError: e),
      );
    }
  }

  /// Pull-to-refresh: re-fetch page 1 keeping the current filters.
  Future<void> refresh() async {
    final current = state.value;
    final status = current?.statusFilter;
    final search = current?.searchQuery ?? '';
    state = const AsyncValue<ExpenseClaimsListState>.loading();
    await _fetchPageOne(status: status, search: search);
  }

  /// Shared page-1 fetch used by the filter / search / refresh paths.
  Future<void> _fetchPageOne({
    required ExpenseClaimStatus? status,
    required String search,
  }) async {
    try {
      final page = await ref.read(expenseRepositoryProvider).getClaimsPage(
        limit: _kExpenseClaimsPageSize,
        status: status,
        search: search.isEmpty ? null : search,
      );
      state = AsyncValue<ExpenseClaimsListState>.data(
        ExpenseClaimsListState(
          items: page.items,
          nextCursor: page.nextCursor,
          statusFilter: status,
          searchQuery: search,
        ),
      );
    } on Object catch (e, st) {
      state = AsyncValue<ExpenseClaimsListState>.error(e, st);
    }
  }

  /// Insert [claim] at the head of `items` after a successful add. Skips
  /// the insert when the active status filter wouldn't include the row
  /// (a new claim is always PENDING) so the optimistic row never violates
  /// the current filter.
  void prependLocal(ExpenseClaim claim) {
    final current = state.value;
    if (current == null) return;
    if (current.statusFilter != null &&
        current.statusFilter != claim.status) {
      return;
    }
    if (current.items.any((c) => c.id == claim.id)) return;
    state = AsyncValue<ExpenseClaimsListState>.data(
      current.copyWith(items: <ExpenseClaim>[claim, ...current.items]),
    );
  }

  /// Replace the row matching [claim].id with [claim]. No-op when the
  /// claim isn't currently visible. Called after a successful edit.
  void replaceLocal(ExpenseClaim claim) {
    final current = state.value;
    if (current == null) return;
    final idx = current.items.indexWhere((c) => c.id == claim.id);
    if (idx == -1) return;
    final next = <ExpenseClaim>[...current.items];
    next[idx] = claim;
    state = AsyncValue<ExpenseClaimsListState>.data(
      current.copyWith(items: next),
    );
  }
}

/// Resolves a single claim by id from the currently-loaded items. Returns
/// `null` when the list hasn't resolved yet or the id isn't present
/// (deep-link callers pass the claim via `extra` to avoid the former).
@riverpod
ExpenseClaim? expenseClaimById(Ref ref, String id) {
  final items =
      ref.watch(expenseClaimsListProvider).value?.items ??
          const <ExpenseClaim>[];
  for (final claim in items) {
    if (claim.id == id) return claim;
  }
  return null;
}

/// The org-managed expense-category catalogue feeding the picker. Reps
/// only read it (admins manage it from the web). Future so the picker's
/// `onBeforeOpen` can await a populated list before opening the sheet.
@riverpod
Future<List<String>> expenseCategories(Ref ref) async {
  return ref.watch(expenseRepositoryProvider).getCategories();
}

/// Customers offered in the optional "Select party" picker, mapped from
/// the live customers list to the slim [ExpenseParty] shape the form
/// already consumes. Watching [partiesListVisibleProvider] auto-loads the
/// first page of customers on demand (same source the notes link picker
/// uses).
@riverpod
List<ExpenseParty> expenseParties(Ref ref) {
  final parties =
      ref.watch(partiesListVisibleProvider).value ?? const <Party>[];
  return parties
      .map((p) => ExpenseParty(id: p.id, name: p.name, address: p.address))
      .toList(growable: false);
}
