import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/visit_formatting.dart';

/// Started / Ended / Duration figures in a soft strip — the beat-plan stop
/// card's time summary, reused on the home carousel card and the detail page.
/// For an active visit only "Started" carries a value; the others read "—".
class VisitTimesStrip extends StatelessWidget {
  const VisitTimesStrip({required this.visit, super.key});

  final UnplannedVisit visit;

  @override
  Widget build(BuildContext context) {
    final active = visit.isInProgress;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          _StatColumn(
            label: 'Started',
            value: formatVisitTime(visit.startedAt),
            icon: Icons.play_circle_outline_rounded,
          ),
          _divider(),
          _StatColumn(
            label: 'Ended',
            value: active ? '—' : formatVisitTime(visit.stoppedAt),
            icon: Icons.stop_circle_outlined,
          ),
          _divider(),
          _StatColumn(
            label: 'Duration',
            value: active ? '—' : formatVisitDuration(visit.durationSeconds),
            icon: Icons.timer_outlined,
            valueColor: AppColors.primary,
            iconColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1.w, height: 32.h, color: AppColors.border);
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 14.sp,
                color: iconColor ?? AppColors.textSecondary,
              ),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
