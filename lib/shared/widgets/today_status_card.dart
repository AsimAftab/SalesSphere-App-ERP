import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// A shared surface for displaying a top-level daily status.
/// Contains an icon, title, a dynamic status badge, and an optional
/// sub-widget below the badge (e.g., for showing timestamps).
class TodayStatusCard extends StatelessWidget {
  const TodayStatusCard({
    required this.icon,
    required this.title,
    required this.statusBadge,
    this.trailingWidget,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget statusBadge;
  final Widget? trailingWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                color: AppColors.textSecondary,
                size: 22.sp,
              ),
              SizedBox(width: 12.w),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              statusBadge,
            ],
          ),
          if (trailingWidget != null) ...<Widget>[
            SizedBox(height: 6.h),
            Align(
              alignment: Alignment.centerRight,
              child: trailingWidget!,
            ),
          ],
        ],
      ),
    );
  }
}
