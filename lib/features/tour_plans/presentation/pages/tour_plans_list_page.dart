import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/tour_plans/domain/tour_plan.dart';
import 'package:sales_sphere_erp/features/tour_plans/presentation/providers/tour_plans_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_search_filter.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/refreshable_list.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Per-status colour palette for the badge on each list-row card.
/// Matches the leaves module so the two list surfaces read as the same
/// family — pending amber, approved green, rejected red.
({Color fg, Color bg}) _statusPalette(TourPlanStatus s) => switch (s) {
  TourPlanStatus.pending => (fg: AppColors.warning, bg: AppColors.warning),
  TourPlanStatus.approved => (fg: AppColors.green500, bg: AppColors.green500),
  TourPlanStatus.rejected => (fg: AppColors.error, bg: AppColors.error),
};

class TourPlansListPage extends ConsumerStatefulWidget {
  const TourPlansListPage({super.key});

  @override
  ConsumerState<TourPlansListPage> createState() => _TourPlansListPageState();
}

class _TourPlansListPageState extends ConsumerState<TourPlansListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  /// `null` means "All" — no status filter applied. Otherwise the list
  /// is narrowed to plans whose [TourPlan.status] matches.
  TourPlanStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilter =>
      _query.trim().isNotEmpty || _statusFilter != null;

  List<TourPlan> _applyFilters(List<TourPlan> source) {
    final byStatus = _statusFilter == null
        ? source
        : source.where((p) => p.status == _statusFilter);
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return byStatus.toList(growable: false);
    return byStatus
        .where((p) => p.placeOfVisit.toLowerCase().contains(q))
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
    final plansAsync = ref.watch(tourPlansListProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: PrimaryFabButton(
          label: 'Add Tour Plan',
          onPressed: () => context.push(Routes.addTourPlan),
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
                      hintText: 'Search by place of visit',
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
                    child: PrimarySearchFilter<TourPlanStatus?>(
                      selected: _statusFilter,
                      onChanged: (next) =>
                          setState(() => _statusFilter = next),
                      options: const <SearchFilterOption<TourPlanStatus?>>[
                        SearchFilterOption<TourPlanStatus?>(
                          value: null,
                          label: 'All Requests',
                          icon: Icons.list_alt_rounded,
                        ),
                        SearchFilterOption<TourPlanStatus?>(
                          value: TourPlanStatus.pending,
                          label: 'Pending',
                          icon: Icons.hourglass_empty_rounded,
                          iconColor: AppColors.warning,
                        ),
                        SearchFilterOption<TourPlanStatus?>(
                          value: TourPlanStatus.approved,
                          label: 'Approved',
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: AppColors.green500,
                        ),
                        SearchFilterOption<TourPlanStatus?>(
                          value: TourPlanStatus.rejected,
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
                        'My Plans',
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
                    child: RefreshableList<TourPlan>(
                      async: plansAsync,
                      filter: _applyFilters,
                      onRefresh: () async {
                        ref.invalidate(tourPlansListProvider);
                        await ref.read(tourPlansListProvider.future);
                      },
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h),
                      itemBuilder: (context, plan) => _TourPlanCard(
                        plan: plan,
                        onTap: () => context.push(
                          Routes.tourPlanDetailPath(plan.id),
                          extra: plan,
                        ),
                      ),
                      skeletonItemBuilder: (_, __) => _TourPlanCard(
                        plan: _placeholderTourPlan,
                        onTap: () {},
                      ),
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
            'Tour Plans',
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

class _TourPlanCard extends StatelessWidget {
  const _TourPlanCard({required this.plan, required this.onTap});

  final TourPlan plan;
  final VoidCallback onTap;

  /// Always shows the full date on both ends ("04 May 2026 - 08 May
  /// 2026") so the user reads the range unambiguously, without having
  /// to re-parse abbreviated forms when months or years differ.
  String _dateRange() {
    final fmt = DateFormat('dd MMM yyyy');
    return '${fmt.format(plan.startDate)} - ${fmt.format(plan.endDate)}';
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
                      Icons.location_on_outlined,
                      color: AppColors.textPrimary,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        plan.placeOfVisit,
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
                    _StatusBadge(status: plan.status),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TourPlanStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = _statusPalette(status);
    // `Skeleton.replace` swaps the colored pill for a neutral bone
    // while the list is loading — without this, the tinted background
    // and bold-coloured text ignore the skeletonizer wash and read as
    // real content over a "loading" row.
    return Skeleton.replace(
      replacement: Bone(
        width: 64.w,
        height: 22.h,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: palette.bg.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          tourPlanStatusLabel(status),
          style: TextStyle(
            color: palette.fg,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// Sample plan fed to [_TourPlanCard] when the list is loading.
/// Skeletonizer paints text bones over the rendered place/dates.
final _placeholderTourPlan = TourPlan(
  id: '',
  placeOfVisit: 'Loading place',
  startDate: DateTime(2026),
  endDate: DateTime(2026),
  purpose: 'Loading purpose',
  status: TourPlanStatus.pending,
  createdAt: DateTime(2026),
);

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilter});

  /// True when the empty result is the consequence of an active search
  /// query or status filter, rather than the source list being
  /// genuinely empty. Drives the copy: the "tap Add Tour Plan" prompt
  /// only makes sense for the latter.
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          hasActiveFilter
              ? 'No tour plans match the current filters.'
              : 'No tour plans yet — tap "Add Tour Plan" to submit one.',
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
          "Couldn't load tour plans. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}
