import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_summary.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';

/// White card stacked under the legend on the home page. Six stat
/// tiles arranged 2 rows × 3 cols, followed by an outlined "View
/// Details" button that opens the month-list page.
class MonthlySummaryCard extends StatelessWidget {
  const MonthlySummaryCard({required this.summary, super.key});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final pct = summary.attendancePct;
    // Whole-percent format keeps the tile compact; only show one
    // decimal when the fraction would otherwise round to zero.
    final pctLabel = pct >= 1
        ? '${pct.round()}%'
        : pct > 0
            ? '${pct.toStringAsFixed(1)}%'
            : '0%';

    final tiles = <_StatTile>[
      _StatTile(value: '${summary.present}', label: 'Present'),
      _StatTile(value: '${summary.absent}', label: 'Absent'),
      _StatTile(value: '${summary.leave}', label: 'Leave'),
      _StatTile(value: '${summary.halfDay}', label: 'Half-Day'),
      _StatTile(value: '${summary.weeklyOff}', label: 'Weekend'),
      _StatTile(value: pctLabel, label: 'Attendance'),
    ];

    return SectionCard(
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.trending_up_rounded,
              color: AppColors.secondary,
              size: 20.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'Monthly Summary',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        for (var row = 0; row < 2; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row == 0 ? 14.h : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (var col = 0; col < 3; col++) ...<Widget>[
                  Expanded(child: tiles[row * 3 + col]),
                  if (col < 2)
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
        OutlinedCustomButton(
          label: 'View Details',
          onPressed: () => context.push(Routes.attendanceDetails),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
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
