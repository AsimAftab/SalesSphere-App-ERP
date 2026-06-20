import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

class SummaryStatTile {
  const SummaryStatTile({required this.value, required this.label});
  final String value;
  final String label;
}

class SummaryStatsCard extends StatelessWidget {
  const SummaryStatsCard({
    required this.title,
    required this.icon,
    required this.stats,
    required this.crossAxisCount,
    required this.onViewDetails,
    this.iconColor = AppColors.blue500,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<SummaryStatTile> stats;
  final int crossAxisCount;
  final VoidCallback onViewDetails;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final rowsCount = (stats.length / crossAxisCount).ceil();

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: iconColor, size: 22.sp),
              SizedBox(width: 12.w),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          for (var r = 0; r < rowsCount; r++)
            Padding(
              padding: EdgeInsets.only(bottom: r < rowsCount - 1 ? 14.h : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (var c = 0; c < crossAxisCount; c++) ...<Widget>[
                    Expanded(
                      child: (r * crossAxisCount + c < stats.length)
                          ? _buildStat(stats[r * crossAxisCount + c])
                          : const SizedBox.shrink(),
                    ),
                    if (c < crossAxisCount - 1)
                      Container(
                        width: 1,
                        height: 36.h,
                        color: AppColors.border,
                      ),
                  ],
                ],
              ),
            ),
          SizedBox(height: 18.h),
          OutlinedCustomButton(onPressed: onViewDetails, label: 'View Details'),
        ],
      ),
    );
  }

  Widget _buildStat(SummaryStatTile stat) {
    return Column(
      children: <Widget>[
        Text(
          stat.value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          stat.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
