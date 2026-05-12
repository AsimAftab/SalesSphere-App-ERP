import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/attendance_status_pill.dart';

/// Compact "Today's Status" surface at the top of the home page.
/// Renders a neutral "Not Checked In" pill when there's no record,
/// the status pill once the user has checked in.
class TodayStatusCard extends StatelessWidget {
  const TodayStatusCard({required this.today, super.key});

  final AttendanceRecord? today;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.access_time_rounded,
            color: AppColors.textSecondary,
            size: 22.sp,
          ),
          SizedBox(width: 12.w),
          Text(
            "Today's Status",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (today == null)
            const NeutralStatusPill(label: 'Not Checked In')
          else
            AttendanceStatusPill(status: today!.status),
        ],
      ),
    );
  }
}
