import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/leaves/domain/leave.dart';
import 'package:sales_sphere_erp/features/leaves/presentation/providers/leaves_providers.dart';
import 'package:sales_sphere_erp/features/leaves/presentation/widgets/leave_category_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_search_filter.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/refreshable_list.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Per-status colour palette for the badge on each list-row card.
/// Lives next to the page so the badge reads at a glance — pending is
/// neutral/warning amber, approved is green, rejected is red.
({Color fg, Color bg}) _statusPalette(LeaveStatus s) => switch (s) {
  LeaveStatus.pending => (fg: AppColors.warning, bg: AppColors.warning),
  LeaveStatus.approved => (fg: AppColors.green500, bg: AppColors.green500),
  LeaveStatus.rejected => (fg: AppColors.error, bg: AppColors.error),
};

class LeavesListPage extends ConsumerStatefulWidget {
  const LeavesListPage({super.key});

  @override
  ConsumerState<LeavesListPage> createState() => _LeavesListPageState();
}

class _LeavesListPageState extends ConsumerState<LeavesListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  /// `null` means "All" — no status filter applied. Otherwise the list
  /// is narrowed to leaves whose [Leave.status] matches.
  LeaveStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilter =>
      _query.trim().isNotEmpty || _statusFilter != null;

  List<Leave> _applyFilters(List<Leave> source) {
    final byStatus = _statusFilter == null
        ? source
        : source.where((l) => l.status == _statusFilter);
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return byStatus.toList(growable: false);
    return byStatus
        .where(
          (l) =>
              leaveCategoryLabel(l.category).toLowerCase().contains(q) ||
              l.reason.toLowerCase().contains(q),
        )
        .toList(growable: false);
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
    final leavesAsync = ref.watch(leavesListProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: PrimaryFabButton(
          label: 'Apply Leave',
          onPressed: () => context.push(Routes.addLeave),
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
                    child: PrimarySearchFilter<LeaveStatus?>(
                      selected: _statusFilter,
                      onChanged: (next) =>
                          setState(() => _statusFilter = next),
                      options: const <SearchFilterOption<LeaveStatus?>>[
                        SearchFilterOption<LeaveStatus?>(
                          value: null,
                          label: 'All Requests',
                          icon: Icons.list_alt_rounded,
                        ),
                        SearchFilterOption<LeaveStatus?>(
                          value: LeaveStatus.pending,
                          label: 'Pending',
                          icon: Icons.hourglass_empty_rounded,
                          iconColor: AppColors.warning,
                        ),
                        SearchFilterOption<LeaveStatus?>(
                          value: LeaveStatus.approved,
                          label: 'Approved',
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: AppColors.green500,
                        ),
                        SearchFilterOption<LeaveStatus?>(
                          value: LeaveStatus.rejected,
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
                        'Leave Requests',
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
                    child: RefreshableList<Leave>(
                      async: leavesAsync,
                      filter: _applyFilters,
                      onRefresh: () async {
                        ref.invalidate(leavesListProvider);
                        await ref.read(leavesListProvider.future);
                      },
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h),
                      itemBuilder: (context, leave) => _LeaveCard(
                        leave: leave,
                        onTap: () => context.push(
                          Routes.leaveDetailPath(leave.id),
                          extra: leave,
                        ),
                      ),
                      skeletonItemBuilder: (_, __) =>
                          _LeaveCard(leave: _placeholderLeave, onTap: () {}),
                      emptyBuilder: (_) =>
                          _EmptyState(hasActiveFilter: _hasActiveFilter),
                      errorBuilder: (_, __, ___) => const _ErrorState(),
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
            'Leave Requests',
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

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.leave, required this.onTap});

  final Leave leave;
  final VoidCallback onTap;

  /// Always shows the full date on both ends ("04 May 2026 - 08 May
  /// 2026") so the user reads the range unambiguously, without having
  /// to re-parse abbreviated forms when the months or years differ.
  String _dateRange() {
    final start = leave.startDate;
    final end = leave.endDate;
    final fmt = DateFormat('dd MMM yyyy');
    if (end == null) return fmt.format(start);
    return '${fmt.format(start)} - ${fmt.format(end)}';
  }

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
                    Icon(
                      leaveCategoryIcon(leave.category),
                      color: AppColors.textPrimary,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        leaveCategoryLabel(leave.category),
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
                      label: leaveStatusLabel(leave.status),
                      color: _statusPalette(leave.status).fg,
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.textSecondary,
                      size: 14.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _dateRange(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
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



/// Sample leave fed to [_LeaveCard] when the list is loading.
/// Skeletonizer paints text bones over the rendered title/dates.
final _placeholderLeave = Leave(
  id: '',
  category: LeaveCategory.others,
  startDate: DateTime(2026),
  reason: 'Loading reason',
  status: LeaveStatus.pending,
  createdAt: DateTime(2026),
);

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilter});

  /// True when the empty result is the consequence of an active search
  /// query or status filter, rather than the source list being
  /// genuinely empty. Drives the copy: the "tap Apply Leave" prompt
  /// only makes sense for the latter.
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          hasActiveFilter
              ? 'No leave requests match the current filters.'
              : 'No leave requests yet — tap "Apply Leave" to submit one.',
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
          "Couldn't load leave requests. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}
