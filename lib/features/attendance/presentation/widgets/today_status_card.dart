import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/attendance_status_pill.dart';

/// Compact "Today's Status" surface at the top of the home page.
/// Pill flips through the live check-in flow:
///   * `Not Checked In` — no record yet
///   * `Checked In`    — check-in recorded, no check-out yet (green)
///   * `Checked Out`   — both recorded for today (blue)
/// When a check-in exists, a small right-aligned line under the pill
/// shows the in / out times so the user can confirm what was logged
/// without leaving the home page.
class TodayStatusCard extends StatelessWidget {
  const TodayStatusCard({required this.today, super.key});

  final AttendanceRecord? today;

  @override
  Widget build(BuildContext context) {
    final record = today;
    final hasCheckIn = record?.hasCheckIn ?? false;
    final hasCheckOut = record?.hasCheckOut ?? false;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
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
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (hasCheckOut)
                const _CheckStatePill(
                  label: 'Checked Out',
                  accent: AppColors.blue500,
                )
              else if (hasCheckIn)
                const _CheckStatePill(
                  label: 'Checked In',
                  accent: AppColors.green500,
                )
              else
                const NeutralStatusPill(label: 'Not Checked In'),
            ],
          ),
          if (hasCheckIn) ...<Widget>[
            SizedBox(height: 6.h),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatTimes(record!),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Inline times string displayed under the pill. Renders the
  /// check-in alone before checkout lands; once checked out the
  /// check-out is appended after a separator so both stamps fit on
  /// one line — matches the design's `10:03 AM | 11:58 AM` shape.
  String _formatTimes(AttendanceRecord r) {
    final fmt = DateFormat('hh:mm a');
    final inAt = fmt.format(r.checkInAt!);
    final outAt = r.checkOutAt;
    return outAt == null ? inAt : '$inAt | ${fmt.format(outAt)}';
  }
}

/// Coloured pill for the live check-in flow. Mirrors
/// `AttendanceStatusPill`'s shape so it slots into the same row without
/// fighting visually.
class _CheckStatePill extends StatelessWidget {
  const _CheckStatePill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(40.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
