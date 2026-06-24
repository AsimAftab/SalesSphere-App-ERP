import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/constants/app_sizes.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';
import 'package:sales_sphere_erp/features/expenses/presentation/providers/expenses_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_search_filter.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// `Rs 1,240` style formatter for claim amounts.
final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

/// Pixel buffer above `maxScrollExtent` at which we kick off the next page.
/// 300px ≈ a couple of card heights — gives the network call a head start
/// before the user actually hits the bottom.
const double _kLoadMoreTriggerPx = 300;

/// Search debounce. 300ms is the codebase's sweet spot (matches parties).
const Duration _kSearchDebounce = Duration(milliseconds: 300);

/// Per-status badge colour. Mirrors the tour-plan / leaves modules so the
/// status pill reads as the same family — pending amber, approved green,
/// rejected red.
Color _statusColor(ExpenseClaimStatus s) => switch (s) {
  ExpenseClaimStatus.pending => AppColors.warning,
  ExpenseClaimStatus.approved => AppColors.green500,
  ExpenseClaimStatus.rejected => AppColors.error,
};

class ExpenseClaimsListPage extends ConsumerStatefulWidget {
  const ExpenseClaimsListPage({super.key});

  @override
  ConsumerState<ExpenseClaimsListPage> createState() =>
      _ExpenseClaimsListPageState();
}

class _ExpenseClaimsListPageState
    extends ConsumerState<ExpenseClaimsListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _hasUserAdvanced = false;

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
    final state = ref.read(expenseClaimsListProvider).value;
    if (state == null || !state.hasMore || state.isLoadingMore) return;
    _hasUserAdvanced = true;
    ref.read(expenseClaimsListProvider.notifier).loadMore();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_kSearchDebounce, () {
      if (!mounted) return;
      _hasUserAdvanced = false;
      ref.read(expenseClaimsListProvider.notifier).setSearch(value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {});
    _hasUserAdvanced = false;
    ref.read(expenseClaimsListProvider.notifier).setSearch('');
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _onRefresh() async {
    _hasUserAdvanced = false;
    await ref.read(expenseClaimsListProvider.notifier).refresh();
  }

  void _onStatusFilterChanged(ExpenseClaimStatus? next) {
    _hasUserAdvanced = false;
    ref.read(expenseClaimsListProvider.notifier).setStatusFilter(next);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.more);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(expenseClaimsListProvider);
    final selectedFilter = listAsync.value?.statusFilter;

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: PrimaryFabButton(
          label: 'Add Expense',
          onPressed: () => context.push(Routes.addExpenseClaim),
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
                              onPressed: _clearSearch,
                              tooltip: 'Clear search',
                            ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimarySearchFilter<ExpenseClaimStatus?>(
                      selected: selectedFilter,
                      onChanged: _onStatusFilterChanged,
                      options: const <SearchFilterOption<ExpenseClaimStatus?>>[
                        SearchFilterOption<ExpenseClaimStatus?>(
                          value: null,
                          label: 'All Claims',
                          icon: Icons.list_alt_rounded,
                        ),
                        SearchFilterOption<ExpenseClaimStatus?>(
                          value: ExpenseClaimStatus.pending,
                          label: 'Pending',
                          icon: Icons.hourglass_empty_rounded,
                          iconColor: AppColors.warning,
                        ),
                        SearchFilterOption<ExpenseClaimStatus?>(
                          value: ExpenseClaimStatus.approved,
                          label: 'Approved',
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: AppColors.green500,
                        ),
                        SearchFilterOption<ExpenseClaimStatus?>(
                          value: ExpenseClaimStatus.rejected,
                          label: 'Rejected',
                          icon: Icons.cancel_outlined,
                          iconColor: AppColors.error,
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
                        'My Claims',
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
                    child: _ClaimsBody(
                      listAsync: listAsync,
                      scrollController: _scrollController,
                      hasUserAdvanced: _hasUserAdvanced,
                      onRefresh: _onRefresh,
                      onRetryLoadMore: () => ref
                          .read(expenseClaimsListProvider.notifier)
                          .loadMore(),
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
}

class _ClaimsBody extends StatelessWidget {
  const _ClaimsBody({
    required this.listAsync,
    required this.scrollController,
    required this.hasUserAdvanced,
    required this.onRefresh,
    required this.onRetryLoadMore,
  });

  final AsyncValue<ExpenseClaimsListState> listAsync;
  final ScrollController scrollController;
  final bool hasUserAdvanced;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetryLoadMore;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h);

    Widget wrapRefresh(Widget child) => RefreshIndicator(
          onRefresh: onRefresh,
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: child,
        );

    // Initial load — paint a skeleton list. Pull-to-refresh is still
    // available so a stuck initial fetch can be retried.
    if (listAsync.isLoading && !listAsync.hasValue) {
      return wrapRefresh(_SkeletonList(padding: padding));
    }

    if (listAsync.hasError && !listAsync.hasValue) {
      return wrapRefresh(
        _SingleScroll(padding: padding, child: const _ErrorState()),
      );
    }

    final state = listAsync.requireValue;
    final items = state.items;
    final hasActiveFilter =
        state.searchQuery.isNotEmpty || state.statusFilter != null;

    if (items.isEmpty) {
      return wrapRefresh(
        _SingleScroll(
          padding: padding,
          child: _EmptyState(hasActiveFilter: hasActiveFilter),
        ),
      );
    }

    return wrapRefresh(
      ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: padding,
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return _LoadMoreFooter(
              hasMore: state.hasMore,
              isLoadingMore: state.isLoadingMore,
              loadMoreError: state.loadMoreError,
              hasUserAdvanced: hasUserAdvanced,
              onRetry: onRetryLoadMore,
            );
          }
          final claim = items[index];
          return _ClaimCard(
            claim: claim,
            onTap: () => context.push(
              Routes.expenseClaimDetailPath(claim.id),
              extra: claim,
            ),
          );
        },
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: padding,
        itemCount: 5,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (_, __) => _ClaimCard(claim: _placeholderClaim, onTap: () {}),
      ),
    );
  }
}

class _SingleScroll extends StatelessWidget {
  const _SingleScroll({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: padding,
      children: <Widget>[SizedBox(height: 80.h), child],
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.hasUserAdvanced,
    required this.onRetry,
  });

  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final bool hasUserAdvanced;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loadMoreError != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.refresh, color: AppColors.primary, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  "Couldn't load more — tap to retry",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        child: Center(
          child: SizedBox(
            width: 22.r,
            height: 22.r,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (hasMore) {
      // Quietly idle — the scroll listener will trigger loadMore.
      return SizedBox(height: 8.h);
    }
    // No more pages. Only surface the explicit copy after the user has
    // actually advanced past page 1; otherwise it screams "you're done"
    // on every short list, which feels noisy.
    if (!hasUserAdvanced) return SizedBox(height: 8.h);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: Text(
          "You've reached the end",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
        ),
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
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textdark,
              size: 20.sp,
            ),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          SizedBox(width: 12.w),
          Text(
            'Expense Claims',
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

/// Minimal claim row — the important facts only: what it was for (title),
/// how much (amount), when (date) and where it sits in the approval flow
/// (status badge).
class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim, required this.onTap});

  final ExpenseClaim claim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: AppSizes.listRowHeaderHeight.h,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          claim.title,
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
                      StatusBadge(
                        label: expenseClaimStatusLabel(claim.status),
                        color: _statusColor(claim.status),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: <Widget>[
                    Text(
                      _currency.format(claim.amount),
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
                      DateFormat('dd MMM yyyy').format(claim.date),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
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

/// Sample claim fed to [_ClaimCard] while the list is loading.
/// Skeletonizer paints bones over the rendered title / amount / date.
final _placeholderClaim = ExpenseClaim(
  id: '',
  title: 'Loading expense title',
  amount: 1000,
  date: DateTime(2026),
  category: 'Travel',
  status: ExpenseClaimStatus.pending,
  createdAt: DateTime(2026),
);

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilter});

  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.receipt_long_outlined,
      title: hasActiveFilter ? 'No matches' : 'No expense claims yet',
      message: hasActiveFilter
          ? 'No expense claims match the current filters.'
          : 'Tap "Add Expense" to log your first one.',
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
          "Couldn't load expense claims. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}
