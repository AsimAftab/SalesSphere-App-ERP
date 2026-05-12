import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';

/// Pill-shaped status badge used by the hero card, the list cards,
/// and the today card. The palette extension is the single source for
/// icon + accent, so all surfaces stay in lockstep.
class AttendanceStatusPill extends StatelessWidget {
  const AttendanceStatusPill({
    required this.status,
    this.showIcon = true,
    super.key,
  });

  final AttendanceStatus status;

  /// Hide the leading checkmark when stacking the pill next to a
  /// bigger icon (e.g. the day-detail hero card already shows a 56 px
  /// status icon above the pill).
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final p = status.palette;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(40.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showIcon) ...<Widget>[
            Icon(p.icon, color: p.accent, size: 14.sp),
            SizedBox(width: 6.w),
          ],
          Text(
            p.label,
            style: TextStyle(
              color: p.accent,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Variant for "Not Checked In" / pending states where no
/// `AttendanceStatus` applies yet.
class NeutralStatusPill extends StatelessWidget {
  const NeutralStatusPill({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.greyLight,
        borderRadius: BorderRadius.circular(40.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
