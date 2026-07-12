import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_drill_down_record.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';
import 'package:sales_sphere_erp/features/targets/presentation/providers/targets_providers.dart';

/// Family key for one drill-down: the server keys on metric + period, not the
/// assignment id. A record gives the structural `==` the `.family` cache
/// needs.
typedef TargetDrillDownQuery = ({
  TargetMetric metric,
  DateTime periodStart,
  DateTime periodEnd,
});

/// Cursor-paginated drill-down state. Records are held directly — the
/// drill-down is network-only, with no drift backing.
class TargetDrillDownState {
  const TargetDrillDownState({
    this.records = const <TargetDrillDownRecord>[],
    this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<TargetDrillDownRecord> records;

  /// Opaque server cursor; null once the last page has been loaded.
  final String? nextCursor;

  final bool isLoadingMore;

  /// A failed `loadMore` lands here (instead of AsyncError) so the records
  /// already on screen stay visible behind a retry row.
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;

  TargetDrillDownState copyWith({
    List<TargetDrillDownRecord>? records,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return TargetDrillDownState(
      records: records ?? this.records,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

/// First page loads in [build]; [loadMore] appends subsequent pages.
/// Riverpod 3 family: the query arrives via the constructor tear-off.
class TargetDrillDownList extends AsyncNotifier<TargetDrillDownState> {
  TargetDrillDownList(this.query);

  final TargetDrillDownQuery query;

  @override
  Future<TargetDrillDownState> build() async {
    final slice = await ref.read(targetsRepositoryProvider).getDrillDown(
          metric: query.metric,
          periodStart: query.periodStart,
          periodEnd: query.periodEnd,
        );
    return TargetDrillDownState(
      records: slice.items,
      nextCursor: slice.nextCursor,
    );
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.isLoadingMore) return;
    state = AsyncValue<TargetDrillDownState>.data(
      s.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final slice = await ref.read(targetsRepositoryProvider).getDrillDown(
            metric: query.metric,
            periodStart: query.periodStart,
            periodEnd: query.periodEnd,
            cursor: s.nextCursor,
          );
      state = AsyncValue<TargetDrillDownState>.data(
        s.copyWith(
          records: <TargetDrillDownRecord>[...s.records, ...slice.items],
          nextCursor: slice.nextCursor,
          clearNextCursor: slice.nextCursor == null,
          isLoadingMore: false,
        ),
      );
    } on Object catch (e) {
      state = AsyncValue<TargetDrillDownState>.data(
        s.copyWith(isLoadingMore: false, loadMoreError: e),
      );
    }
  }
}

final targetDrillDownListProvider = AsyncNotifierProvider.autoDispose
    .family<TargetDrillDownList, TargetDrillDownState, TargetDrillDownQuery>(
  TargetDrillDownList.new,
);
