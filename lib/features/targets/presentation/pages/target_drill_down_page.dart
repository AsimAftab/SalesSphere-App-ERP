import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_drill_down_generator.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_drill_down_record.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Navigation argument class for [TargetDrillDownPage].
class TargetDrillDownArgs {
  const TargetDrillDownArgs({
    required this.target,
    this.periodLabel,
  });

  final TargetItem target;
  final String? periodLabel;
}

/// Dedicated Drill-Down screen displaying individual records that make up
/// an assigned target's Total Actual value.
class TargetDrillDownPage extends ConsumerWidget {
  const TargetDrillDownPage({
    required this.target,
    this.periodLabel,
    super.key,
  });

  final TargetItem target;
  final String? periodLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final employeeName = authState.asData?.value?.fullName ?? 'Vikram Sharma';
    final effectivePeriod = periodLabel ??
        (target.interval.toLowerCase() == 'daily'
            ? 'July 11, 2026'
            : 'July 2026');

    final records = TargetDrillDownGenerator.generateRecords(target);
    final dynamicHeader =
        TargetDrillDownGenerator.getDynamicListHeader(target.rule);

    final progressPercentage = target.progressPercentage;
    final Color progressColor;
    if (target.actualValue == 0) {
      progressColor = AppColors.error;
    } else if (progressPercentage >= 100) {
      progressColor = AppColors.success;
    } else {
      progressColor = AppColors.warning;
    }

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
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 36.h),
                      children: <Widget>[
                        // Top Summary Block
                        _buildSummaryBlock(
                          context: context,
                          employeeName: employeeName,
                          period: effectivePeriod,
                          progressColor: progressColor,
                        ),
                        SizedBox(height: 24.h),

                        // Dynamic List Subheader
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                '${records.length} Records',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
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
                      ],
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

  Widget _buildSummaryBlock({
    required BuildContext context,
    required String employeeName,
    required String period,
    required Color progressColor,
  }) {
    final isDaily = target.interval.toLowerCase() == 'daily';
    final intervalBadgeColor =
        isDaily ? AppColors.info : AppColors.purple500;
    final initialLetter =
        employeeName.isNotEmpty ? employeeName[0].toUpperCase() : 'V';

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
                    backgroundColor: AppColors.secondary,
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
                label: target.interval,
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
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: target.progressFraction,
              minHeight: 10.h,
              backgroundColor:
                  AppColors.greyLight.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
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
          Container(
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
