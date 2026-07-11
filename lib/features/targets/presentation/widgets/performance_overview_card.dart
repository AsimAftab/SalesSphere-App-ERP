import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';

/// Executive KPI summary card embedded directly in the Targets & Performance page.
class PerformanceOverviewCard extends StatelessWidget {
  const PerformanceOverviewCard({
    required this.targets,
    required this.periodLabel,
    super.key,
  });

  final List<TargetItem> targets;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    // Compute aggregate metrics safely
    final totalCount = targets.length;
    final completedCount = targets.where((t) => t.isCompleted).length;
    final activeCount = totalCount - completedCount;

    double averageProgress = 0;
    if (totalCount > 0) {
      final sumProgress = targets.fold<double>(
        0,
        (acc, item) => acc + item.progressPercentage,
      );
      averageProgress = sumProgress / totalCount;
    }

    // Find Order vs Collection samples or totals
    final orderTargets = targets.where(
      (t) => t.rule.toLowerCase().contains('order'),
    );
    num totalOrdersActual = 0;
    num totalOrdersTarget = 0;
    for (final t in orderTargets) {
      totalOrdersActual += t.actualValue;
      totalOrdersTarget += t.targetValue;
    }

    final collectionTargets = targets.where((t) => t.isCurrency);
    num totalCollectionActual = 0;
    num totalCollectionTarget = 0;
    for (final t in collectionTargets) {
      totalCollectionActual += t.actualValue;
      totalCollectionTarget += t.targetValue;
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: AppColors.primary,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                'Performance Overview',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCell(
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.success,
                  label: 'Progress',
                  value: '${averageProgress.toStringAsFixed(0)}%',
                  subtitle: '$completedCount/$totalCount Done',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MetricCell(
                  icon: Icons.assignment_turned_in_outlined,
                  iconColor: AppColors.primary,
                  label: 'Orders',
                  value: totalOrdersTarget > 0
                      ? '$totalOrdersActual / $totalOrdersTarget'
                      : '$totalOrdersActual Logged',
                  subtitle: 'Order Volume',
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCell(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.fuchsia600,
                  label: 'Collections',
                  value: totalCollectionActual > 0
                      ? 'Rs ${_formatNumber(totalCollectionActual)}'
                      : 'Rs 0',
                  subtitle: totalCollectionTarget > 0
                      ? 'Target: Rs ${_formatNumber(totalCollectionTarget)}'
                      : 'Achieved',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _MetricCell(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: AppColors.warning,
                  label: 'Status',
                  value: '$completedCount Done',
                  subtitle: '$activeCount Active',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatNumber(num val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}k';
    }
    return val.toString();
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                color: iconColor,
                size: 15.sp,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
