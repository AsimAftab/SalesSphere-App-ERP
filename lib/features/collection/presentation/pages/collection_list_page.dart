import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection/presentation/providers/collection_providers.dart';
import 'package:sales_sphere_erp/features/collection/presentation/widgets/collection_sync_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_search_filter.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// `Rs 12,500` style formatter for collected amounts.
final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

/// Pixel buffer above `maxScrollExtent` at which we kick off the next page.
const double _kLoadMoreTriggerPx = 300;

/// Search debounce — 300ms is the house value.
const Duration _kSearchDebounce = Duration(milliseconds: 300);

class CollectionListPage extends ConsumerStatefulWidget {
  const CollectionListPage({super.key});

  @override
  ConsumerState<CollectionListPage> createState() => _CollectionListPageState();
}

class _CollectionListPageState extends ConsumerState<CollectionListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - _kLoadMoreTriggerPx) return;
    final state = ref.read(collectionListProvider).value;
    if (state == null || !state.hasMore || state.isLoadingMore) return;
    ref.read(collectionListProvider.notifier).loadMore();
  }

  /// Search and the payment-mode filter are both applied **server-side** —
  /// the list is cursor-paginated, so filtering the loaded page in Dart would
  /// silently hide matches that live on a later page.
  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_kSearchDebounce, () {
      if (!mounted) return;
      ref.read(collectionListProvider.notifier).setSearch(value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {});
    ref.read(collectionListProvider.notifier).setSearch('');
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.fieldOps);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(collectionListProvider);
    final rows = ref.watch(collectionsListVisibleProvider);
    final modeFilter = listState.value?.paymentModeFilter;
    final hasActiveFilter =
        (listState.value?.searchQuery.isNotEmpty ?? false) ||
        modeFilter != null;

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: PrimaryFabButton(
          label: 'Add Collection',
          onPressed: () => context.push(Routes.addCollection),
        ),
        body: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SvgPicture.asset(
                'assets/images/corner_bubble.svg',
                fit: BoxFit.cover,
                height: 180.h,
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _AppBar(onBack: _back),
                  SizedBox(height: 46.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimaryTextField(
                      controller: _searchController,
                      hintText: 'Search',
                      prefixIcon: Icons.search,
                      onChanged: _onSearchChanged,
                      suffixWidget: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 20.sp,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                _clearSearch();
                                FocusManager.instance.primaryFocus?.unfocus();
                              },
                              tooltip: 'Clear search',
                            ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimarySearchFilter<PaymentMode?>(
                      selected: modeFilter,
                      onChanged: (next) => ref
                          .read(collectionListProvider.notifier)
                          .setPaymentModeFilter(next),
                      options: <SearchFilterOption<PaymentMode?>>[
                        const SearchFilterOption<PaymentMode?>(
                          value: null,
                          label: 'All',
                          icon: Icons.list_alt_rounded,
                        ),
                        for (final m in PaymentMode.values)
                          SearchFilterOption<PaymentMode?>(
                            value: m,
                            label: m.label,
                            icon: m.icon,
                            iconColor: m.accent,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'My Collections',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: _buildBody(
                      listState: listState,
                      rows: rows,
                      hasActiveFilter: hasActiveFilter,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required AsyncValue<CollectionListState> listState,
    required AsyncValue<List<Collection>> rows,
    required bool hasActiveFilter,
  }) {
    final padding = EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h);

    Widget wrapRefresh(Widget child) => RefreshIndicator(
      onRefresh: () => ref.read(collectionListProvider.notifier).refresh(),
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: child,
    );

    // First load — paint a skeleton. Pull-to-refresh stays available so a
    // stuck initial fetch can be retried.
    if (listState.isLoading && !listState.hasValue) {
      return wrapRefresh(
        Skeletonizer(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: padding,
            itemCount: 5,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (_, __) =>
                _CollectionCard(collection: _placeholder, onTap: () {}),
          ),
        ),
      );
    }

    if (listState.hasError && !listState.hasValue) {
      return wrapRefresh(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 80.h, 20.w, 140.h),
          children: const <Widget>[_ErrorState()],
        ),
      );
    }

    // Rows stream out of drift, so a background sync landing (or a cheque
    // status change) re-renders without a refetch.
    final items = rows.value ?? const <Collection>[];
    final state = listState.value;

    if (items.isEmpty) {
      return wrapRefresh(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 80.h, 20.w, 140.h),
          children: <Widget>[_EmptyState(hasActiveFilter: hasActiveFilter)],
        ),
      );
    }

    final showFooter =
        (state?.isLoadingMore ?? false) || (state?.loadMoreError != null);

    return wrapRefresh(
      ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: padding,
        itemCount: items.length + (showFooter ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return _LoadMoreFooter(
              isLoading: state?.isLoadingMore ?? false,
              error: state?.loadMoreError,
              onRetry: () =>
                  ref.read(collectionListProvider.notifier).loadMore(),
            );
          }
          final collection = items[index];
          return _CollectionCard(
            collection: collection,
            onTap: () => context.push(
              Routes.collectionDetailPath(collection.id),
              extra: collection,
            ),
          );
        },
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textdark, size: 20.sp),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          SizedBox(width: 12.w),
          Text(
            'Collection',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Collection row — who the money came from, how it was paid, how much, when,
/// and whether it has made it to the server yet.
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection, required this.onTap});

  final Collection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mode = collection.paymentMode;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        collection.party.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    StatusBadge(label: mode.label, color: mode.accent),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: <Widget>[
                    Text(
                      _currency.format(collection.amount),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.event_outlined,
                      size: 14.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      DateFormat('dd MMM yyyy').format(collection.receivedDate),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: <Widget>[
                    // The receipt number is the row's server identity. While a
                    // create is still queued the server hasn't issued one, so
                    // the slot carries the sync badge instead.
                    if (collection.hasServerIdentity)
                      Text(
                        collection.collectionNo,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    CollectionSyncBadge(
                      syncPending: collection.syncPending,
                      syncError: collection.syncError,
                    ),
                    const Spacer(),
                    StatusBadge(
                      label: collection.status.label,
                      color: collection.status.color,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sample collection fed to [_CollectionCard] while the list is loading.
final _placeholder = Collection(
  id: '',
  collectionNo: 'RCPT-00-0000',
  party: const CollectionParty(
    id: '',
    name: 'Loading party name',
    address: '',
  ),
  amount: 10000,
  receivedDate: DateTime(2026),
  paymentMode: PaymentMode.cash,
  createdAt: DateTime(2026),
);

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Center(
          child: TextButton(
            onPressed: onRetry,
            child: Text(
              "Couldn't load more. Tap to retry.",
              style: TextStyle(color: AppColors.primary, fontSize: 13.sp),
            ),
          ),
        ),
      );
    }
    if (!isLoading) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Center(
        child: SizedBox(
          width: 22.w,
          height: 22.w,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilter});

  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.account_balance_wallet_outlined,
      title: hasActiveFilter ? 'No matches' : 'No collections yet',
      message: hasActiveFilter
          ? 'No collections match the current filters.'
          : 'Tap "Add Collection" to record your first one.',
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          "Couldn't load collections. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}
