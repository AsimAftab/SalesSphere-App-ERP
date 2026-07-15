import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';
import 'package:sales_sphere_erp/features/targets/presentation/widgets/target_progress_color.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';

/// A sleek, modern card displaying an employee's assigned target,
/// status badge (Completed/Active), formatted values (currency/number),
/// and a visual progress bar capped at 100%.
class TargetCard extends StatelessWidget {
  const TargetCard({
    required this.target,
    this.periodLabel,
    this.onTap,
    super.key,
  });

  final TargetItem target;
  final String? periodLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDaily = target.interval == TargetInterval.daily;
    final intervalBadgeLabel = isDaily ? 'Daily' : 'Monthly';
    final intervalBadgeColor =
        isDaily ? AppColors.info : AppColors.purple500;
    final progressFraction = target.progressFraction;
    final progressPercentage = target.progressPercentage;
    final progressColor = targetProgressColor(target);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 18.h),
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
          // Header: Rule name (bold) + Interval Badge (pill)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      target.rule,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (periodLabel != null && periodLabel!.isNotEmpty) ...<Widget>[
                      SizedBox(height: 4.h),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            periodLabel!,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              StatusBadge(
                label: intervalBadgeLabel,
                color: intervalBadgeColor,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Progress numbers: Actual / Target and Percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: target.formattedActual,
                      style: TextStyle(color: progressColor),
                    ),
                    TextSpan(
                      text: ' / ${target.formattedTarget}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${progressPercentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // Horizontal Progress Bar capped at 100%
          Skeleton.replace(
            replacement: Bone(
              height: 10.h,
              width: double.infinity,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 10.h,
                backgroundColor: AppColors.greyLight.withValues(alpha: 0.6),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
