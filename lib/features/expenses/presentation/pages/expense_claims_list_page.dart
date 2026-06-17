import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_category.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';
import 'package:sales_sphere_erp/features/expenses/presentation/providers/expenses_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_search_filter.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// `Rs 1,240` style formatter for claim amounts.
final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

/// Per-status badge colour. Mirrors the tour-plan / leaves modules so
/// the status pill reads as the same family — pending amber, approved
/// green, rejected red.
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
  String _query = '';

  /// `null` means "All" — no status filter applied. Otherwise the list
  /// narrows to claims whose [ExpenseClaim.status] matches.
  ExpenseClaimStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.more);
    }
  }

  /// Apply the in-page search query + status filter against the loaded
  /// claims.
  List<ExpenseClaim> _applyFilters(List<ExpenseClaim> source) {
    final q = _query.trim().toLowerCase();
    return source.where((c) {
      if (_statusFilter != null && c.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.category.label.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  bool get _hasActiveFilter =>
      _query.trim().isNotEmpty || _statusFilter != null;

  @override
  Widget build(BuildContext context) {
    final claimsAsync = ref.watch(expenseClaimsListProvider);

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
                      onChanged: (v) => setState(() => _query = v),
                      suffixWidget: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 20.sp,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                                FocusManager.instance.primaryFocus?.unfocus();
                              },
                              tooltip: 'Clear search',
                            ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimarySearchFilter<ExpenseClaimStatus?>(
                      selected: _statusFilter,
                      onChanged: (next) =>
                          setState(() => _statusFilter = next),
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
                  Expanded(child: _buildBody(claimsAsync)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<ExpenseClaim>> claimsAsync) {
    final padding = EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h);

    Widget wrapRefresh(Widget child) => RefreshIndicator(
          onRefresh: () =>
              ref.read(expenseClaimsListProvider.notifier).refresh(),
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: child,
        );

    // First load — paint a skeleton list. Pull-to-refresh is still
    // available so a stuck initial fetch can be retried.
    if (claimsAsync.isLoading && !claimsAsync.hasValue) {
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
                _ClaimCard(claim: _placeholderClaim, onTap: () {}),
          ),
        ),
      );
    }

    if (claimsAsync.hasError && !claimsAsync.hasValue) {
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

    final items = _applyFilters(claimsAsync.requireValue);
    if (items.isEmpty) {
      return wrapRefresh(
        ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 80.h, 20.w, 140.h),
          children: <Widget>[
            _EmptyState(hasActiveFilter: _hasActiveFilter),
          ],
        ),
      );
    }

    return wrapRefresh(
      ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
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

/// Minimal claim row — the important facts only: what it was for
/// (title), how much (amount), when (date) and where it sits in the
/// approval flow (status badge).
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
                Row(
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
                SizedBox(height: 8.h),
                Row(
                  children: <Widget>[
                    Text(
                      _currency.format(claim.amount),
                      style: TextStyle(
                        color: AppColors.green500,
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
  category: ExpenseCategory.travel,
  status: ExpenseClaimStatus.pending,
  createdAt: DateTime(2026),
);

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilter});

  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          hasActiveFilter
              ? 'No expense claims match the current filters.'
              : 'No expense claims yet — tap "Add Expense" to log your first one.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
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
