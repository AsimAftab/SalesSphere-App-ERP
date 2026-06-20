import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';

/// One row on the month-list page: weekday + date + status pill, a
/// horizontal divider, a check-in / check-out row, then an hours-worked
/// bar. Per-leg locations live on the full day-detail page, not here.
class DayDetailCard extends StatelessWidget {
  const DayDetailCard({
    required this.record,
    required this.onTap,
    super.key,
  });

  final AttendanceRecord record;
  final VoidCallback onTap;

  String _formatHours(Duration? d) {
    if (d == null) return '--';
    final hours = d.inMinutes ~/ 60;
    final minutes = d.inMinutes % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
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
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            DateFormat('EEEE').format(record.date),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            DateFormat('MMM d, yyyy').format(record.date),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: record.status.palette.label,
                      color: record.status.palette.accent,
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
                SizedBox(height: 12.h),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MiniTile(
                        icon: Icons.login_rounded,
                        iconColor: AppColors.green500,
                        label: 'Check-in',
                        value: record.checkInAt == null
                            ? '--:--'
                            : DateFormat('hh:mm a').format(record.checkInAt!),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _MiniTile(
                        icon: Icons.logout_rounded,
                        iconColor: AppColors.red500,
                        label: 'Check-out',
                        value: record.checkOutAt == null
                            ? '--:--'
                            : DateFormat('hh:mm a').format(record.checkOutAt!),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // Hours worked — full-width bar so the figure is never cramped.
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.access_time_rounded,
                          color: AppColors.secondary, size: 18.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'Hours Worked',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatHours(record.hoursWorked),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: iconColor, size: 18.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
