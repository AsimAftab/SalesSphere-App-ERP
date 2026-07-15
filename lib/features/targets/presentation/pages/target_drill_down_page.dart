import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_drill_down_record.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';
import 'package:sales_sphere_erp/features/targets/presentation/providers/target_drill_down_providers.dart';
import 'package:sales_sphere_erp/features/targets/presentation/widgets/target_progress_color.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Navigation argument class for [TargetDrillDownPage].
class TargetDrillDownArgs {
  const TargetDrillDownArgs({required this.target});

  final TargetItem target;
}

/// Dedicated Drill-Down screen displaying the individual server records that
/// make up an assigned target's Total Actual value. Cursor-paginated;
/// network-only (offline shows the error state — only the targets list is
/// cached).
class TargetDrillDownPage extends ConsumerStatefulWidget {
  const TargetDrillDownPage({required this.target, super.key});

  final TargetItem target;

  @override
  ConsumerState<TargetDrillDownPage> createState() =>
      _TargetDrillDownPageState();
}

class _TargetDrillDownPageState extends ConsumerState<TargetDrillDownPage> {
  final ScrollController _scrollController = ScrollController();

  TargetItem get target => widget.target;

  /// The drill-down keys on metric + period — never the assignment id.
  TargetDrillDownQuery get _query => (
        metric: target.metric,
        periodStart: target.periodStart,
        periodEnd: target.periodEnd,
      );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(targetDrillDownListProvider(_query).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final employeeName = authState.asData?.value?.fullName ?? '';
    final recordsAsync = ref.watch(targetDrillDownListProvider(_query));

    final progressColor = targetProgressColor(target);
    final dynamicHeader = drillDownHeaderFor(target.metric);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
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
                  _AppBar(
                    rule: target.rule,
                    onBack: () => context.pop(),
                  ),
                  Expanded(
                    child: recordsAsync.when(
                      data: (state) => _buildContent(
                        context,
                        state: state,
                        employeeName: employeeName,
                        progressColor: progressColor,
                        dynamicHeader: dynamicHeader,
                      ),
                      loading: () => _buildLoading(
                        employeeName: employeeName,
                        progressColor: progressColor,
                        dynamicHeader: dynamicHeader,
                      ),
                      error: (err, _) => _buildError(),
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

  Widget _buildContent(
    BuildContext context, {
    required TargetDrillDownState state,
    required String employeeName,
    required Color progressColor,
    required String dynamicHeader,
  }) {
    final records = state.records;
    final countLabel =
        '${records.length}${state.hasMore ? '+' : ''} Records';

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 36.h),
      children: <Widget>[
        // Top Summary Block
        _buildSummaryBlock(
          context: context,
          employeeName: employeeName,
          period: target.periodLabel,
          progressColor: progressColor,
        ),
        SizedBox(height: 24.h),

        // Dynamic List Subheader & Records Count
        Row(
          children: <Widget>[
            Text(
              dynamicHeader,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            Text(
              countLabel,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),

        // List of Records or Empty State
        if (records.isEmpty)
          _buildEmptyState()
        else
          ...records.map(_buildRecordCard),

        // Pagination footer: spinner while loading, retry row on failure.
        if (state.isLoadingMore)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Center(
              child: SizedBox(
                width: 22.r,
                height: 22.r,
                child: const CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (state.loadMoreError != null)
          _buildLoadMoreRetry(),
      ],
    );
  }

  Widget _buildLoading({
    required String employeeName,
    required Color progressColor,
    required String dynamicHeader,
  }) {
    final placeholder = TargetDrillDownRecord(
      id: 'skeleton',
      primaryTitle: 'ORD-XXXX-XX-0000',
      subtitle: 'Loading party name',
      contributionValue: 1,
      isCurrency: false,
      timestamp: DateTime(2026),
      datePrecision: DatePrecision.day,
    );

    return Skeletonizer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 36.h),
        children: <Widget>[
          _buildSummaryBlock(
            context: context,
            employeeName: employeeName,
            period: target.periodLabel,
            progressColor: progressColor,
          ),
          SizedBox(height: 24.h),
          Text(
            dynamicHeader,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 14.h),
          for (var i = 0; i < 4; i++) _buildRecordCard(placeholder),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, color: AppColors.error, size: 40.sp),
            SizedBox(height: 12.h),
            Text(
              'Failed to load records',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(targetDrillDownListProvider(_query)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreRetry() {
    return InkWell(
      onTap: () =>
          ref.read(targetDrillDownListProvider(_query).notifier).loadMore(),
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.refresh_rounded, color: AppColors.error, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              "Couldn't load more — tap to retry",
              style: TextStyle(
                color: AppColors.error,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBlock({
    required BuildContext context,
    required String employeeName,
    required String period,
    required Color progressColor,
  }) {
    final isDaily = target.interval == TargetInterval.daily;
    final intervalBadgeColor =
        isDaily ? AppColors.info : AppColors.purple500;
    final initialLetter =
        employeeName.isNotEmpty ? employeeName[0].toUpperCase() : '?';

    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Employee Name and Period row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initialLetter,
                      style: TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        employeeName,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        period,
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
              StatusBadge(
                label: isDaily ? 'Daily' : 'Monthly',
                color: intervalBadgeColor,
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Divider(color: AppColors.border.withValues(alpha: 0.5), height: 1),
          SizedBox(height: 16.h),

          // Total Actual section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Total Actual',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    target.formattedActual,
                    style: TextStyle(
                      color: progressColor,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'Target: ${target.formattedTarget}',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // Horizontal Progress Bar
          Skeleton.replace(
            replacement: Bone(
              height: 10.h,
              width: double.infinity,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: LinearProgressIndicator(
                value: target.progressFraction,
                minHeight: 10.h,
                backgroundColor:
                    AppColors.greyLight.withValues(alpha: 0.6),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(TargetDrillDownRecord record) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  record.primaryTitle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (record.subtitle != null &&
                    record.subtitle!.isNotEmpty) ...<Widget>[
                  SizedBox(height: 3.h),
                  Text(
                    record.subtitle!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                SizedBox(height: 6.h),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.access_time_rounded,
                      size: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      record.formattedTimestamp,
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
          SizedBox(width: 12.w),
          Skeleton.replace(
            replacement: Bone(
              width: 60.w,
              height: 28.h,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                record.formattedContribution,
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32.r),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.history_toggle_off_rounded,
            size: 44.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 12.h),
          Text(
            'No Activity Recorded Yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Records contributing to this target will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.rule,
    required this.onBack,
  });

  final String rule;
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
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              '$rule Breakdown',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
