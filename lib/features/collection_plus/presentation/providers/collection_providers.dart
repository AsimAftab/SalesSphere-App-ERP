import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection_plus/data/repositories/collection_plus_repository_impl.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/invoice_due.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';

// Re-export the repository provider so controllers and tests depend on the
// contract surface without importing from `data/`.
export 'package:sales_sphere_erp/features/collection_plus/data/repositories/collection_plus_repository_impl.dart'
    show collectionPlusRepositoryProvider;

part 'collection_providers.g.dart';

const int _kCollectionPlusPageSize = 15;

/// Parties offered in the "Select party" bottom sheet, mapped from the live
/// customers list. (The module used to ship hardcoded fixtures because it was
/// built before the parties API landed.)
@riverpod
List<CollectionPlusParty> collectionPlusParties(Ref ref) {
  final parties = ref.watch(partiesListVisibleProvider).value ?? const <Party>[];
  return parties
      .map(
        (p) => CollectionPlusParty(
          id: p.id,
          name: p.name,
          address: p.address,
          ownerName: p.ownerName,
        ),
      )
      .toList(growable: false);
}

/// Bank catalogue for the cheque / bank-transfer picker — a suggestion list,
/// not an enum.
@riverpod
Future<List<String>> bankNames(Ref ref) =>
    ref.watch(collectionPlusRepositoryProvider).getBankNames();

/// A party's outstanding invoices, oldest-first — the pool the form allocates
/// across.
///
/// **Read from the server, never computed here.** The mock used to derive this
/// by summing allocations across every loaded collection, which was wrong the
/// moment the list outgrew one page and hopeless once two devices were
/// involved. Outstanding is derived server-side on every read, which is also
/// what lets a bounced cheque restore a balance with no compensating row.
///
/// [excludeCollectionId] is **mandatory in the edit flow**. It releases that
/// receipt's own allocations back into the pool. Without it, the collection
/// being edited is still holding down the money it's about to re-allocate, and
/// re-saving it unchanged fails validation every single time.
///
/// Only POSTED invoices are collectible, so an empty list means "nothing to
/// settle yet" — not a bug. A rep's order stays DRAFT until the web app posts
/// it; until then, plain Collection (on-account) is the way to take the money.
///
/// [asOfDate] joins the family key so the pool re-fetches when the rep picks a
/// different Received Date. Pass the picked date and the server caps the read
/// to what was due then — future invoices and future payments are excluded, so
/// a backdated receipt allocates against the balances that existed that day.
@riverpod
Future<List<InvoiceDue>> outstandingInvoicesForParty(
  Ref ref,
  String partyId, {
  String? excludeCollectionId,
  DateTime? asOfDate,
}) {
  return ref
      .watch(collectionPlusRepositoryProvider)
      .getOutstandingInvoices(
        partyId: partyId,
        excludeCollectionId: excludeCollectionId,
        asOfDate: asOfDate,
      );
}

/// Re-hydrate specific invoices by id, keeping rows that are already fully
/// paid — so an invoice this receipt settled still renders in the edit picker.
@riverpod
Future<List<InvoiceDue>> invoiceMeta(
  Ref ref,
  List<String> invoiceIds, {
  String? excludeCollectionId,
}) {
  return ref
      .watch(collectionPlusRepositoryProvider)
      .getInvoiceMeta(
        invoiceIds: invoiceIds,
        excludeCollectionId: excludeCollectionId,
      );
}

/// Session-scoped pagination + filter state. Drift owns row content; this owns
/// order, cursor and filters. Every filter is applied server-side.
class CollectionPlusListState {
  const CollectionPlusListState({
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

  CollectionPlusListState copyWith({
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
    return CollectionPlusListState(
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
class CollectionPlusList extends _$CollectionPlusList {
  @override
  Future<CollectionPlusListState> build() async {
    final page = await ref
        .read(collectionPlusRepositoryProvider)
        .getCollectionsPage(limit: _kCollectionPlusPageSize);
    return CollectionPlusListState(
      loadedIds: page.items.map((c) => c.id).toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }

  Future<void> setPaymentModeFilter(PaymentMode? mode) async {
    final current = state.value;
    if (current != null && current.paymentModeFilter == mode) return;
    final search = current?.searchQuery ?? '';
    state = const AsyncValue<CollectionPlusListState>.loading();
    await _fetchPageOne(paymentMode: mode, search: search);
  }

  Future<void> setSearch(String query) async {
    final trimmed = query.trim();
    final current = state.value;
    if (current != null && current.searchQuery == trimmed) return;
    final mode = current?.paymentModeFilter;
    state = const AsyncValue<CollectionPlusListState>.loading();
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
    state = AsyncValue<CollectionPlusListState>.data(
      s.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final page = await ref
          .read(collectionPlusRepositoryProvider)
          .getCollectionsPage(
            limit: _kCollectionPlusPageSize,
            cursor: s.nextCursor,
            search: s.searchQuery.isEmpty ? null : s.searchQuery,
            paymentMode: s.paymentModeFilter,
          );
      state = AsyncValue<CollectionPlusListState>.data(
        s.copyWith(
          loadedIds: <String>[...s.loadedIds, ...page.items.map((c) => c.id)],
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          isLoadingMore: false,
        ),
      );
    } on Object catch (e) {
      state = AsyncValue<CollectionPlusListState>.data(
        s.copyWith(isLoadingMore: false, loadMoreError: e),
      );
    }
  }

  void prependLocal(CollectionPlus collection) {
    final current = state.value ?? const CollectionPlusListState();
    if (current.paymentModeFilter != null &&
        current.paymentModeFilter != collection.paymentMode) {
      return;
    }
    if (current.loadedIds.contains(collection.id)) return;
    state = AsyncValue<CollectionPlusListState>.data(
      current.copyWith(
        loadedIds: <String>[collection.id, ...current.loadedIds],
      ),
    );
  }

  void removeLocal(String id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue<CollectionPlusListState>.data(
      current.copyWith(
        loadedIds: current.loadedIds
            .where((x) => x != id)
            .toList(growable: false),
      ),
    );
  }

  /// Swap a `local_<uuid>` id for the server-issued one once the outbox drains.
  void replaceLocalId(String localId, String serverId) {
    final current = state.value;
    if (current == null) return;
    final idx = current.loadedIds.indexOf(localId);
    if (idx == -1) return;
    final next = <String>[...current.loadedIds];
    next[idx] = serverId;
    state = AsyncValue<CollectionPlusListState>.data(
      current.copyWith(loadedIds: next),
    );
  }

  Future<void> _fetchPageOne({
    required PaymentMode? paymentMode,
    required String search,
  }) async {
    try {
      final page = await ref
          .read(collectionPlusRepositoryProvider)
          .getCollectionsPage(
            limit: _kCollectionPlusPageSize,
            paymentMode: paymentMode,
            search: search.isEmpty ? null : search,
          );
      state = AsyncValue<CollectionPlusListState>.data(
        CollectionPlusListState(
          loadedIds: page.items.map((c) => c.id).toList(growable: false),
          nextCursor: page.nextCursor,
          searchQuery: search,
          paymentModeFilter: paymentMode,
        ),
      );
    } on Object catch (e, st) {
      state = AsyncValue<CollectionPlusListState>.error(e, st);
    }
  }
}

/// Drift-backed view of the loaded Collection Plus rows, with their
/// allocations. Re-emits when either the rows or the loaded ids change.
@riverpod
Stream<List<CollectionPlus>> collectionPlusListVisible(Ref ref) {
  final ids =
      ref.watch(collectionPlusListProvider).value?.loadedIds ?? const <String>[];
  final dao = ref.watch(collectionsDaoProvider);
  if (ids.isEmpty) {
    return Stream<List<CollectionPlus>>.value(const <CollectionPlus>[]);
  }
  return dao.watchByIds(ids).asyncMap((rows) async {
    final out = <CollectionPlus>[];
    for (final row in rows) {
      out.add(
        collectionPlusRowToDomain(row, await dao.allocationsFor(row.id)),
      );
    }
    return out;
  });
}

/// Detail-page lookup: hydrate, then watch — so the page live-updates when a
/// cheque-status change or a background sync rewrites the row.
@riverpod
Stream<CollectionPlus?> collectionPlusById(Ref ref, String id) async* {
  final dao = ref.watch(collectionsDaoProvider);
  final cached = await dao.findById(id);
  if (cached == null && !id.startsWith('local_')) {
    await ref.read(collectionPlusRepositoryProvider).getCollectionById(id);
  }
  yield* dao.watchById(id).asyncMap((row) async {
    if (row == null) return null;
    return collectionPlusRowToDomain(row, await dao.allocationsFor(row.id));
  });
}
