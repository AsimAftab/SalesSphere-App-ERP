import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';

/// Five colour-coded chips that decode the calendar's status dots.
/// Sits below the calendar on the home page.
class LegendRow extends StatelessWidget {
  const LegendRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16.w,
      runSpacing: 8.h,
      children: <Widget>[
        for (final status in AttendanceStatus.values) _LegendChip(status: status),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final p = status.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10.r,
          height: 10.r,
          decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
        ),
        SizedBox(width: 8.w),
        Text(
          p.label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
