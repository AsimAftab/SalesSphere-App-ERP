import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// White rounded card with chevron-left / month label / chevron-right.
/// Used as the standalone month picker on the details list page (the
/// home page uses the calendar's own internal header instead).
class MonthNavHeader extends StatelessWidget {
  const MonthNavHeader({
    required this.displayedMonth,
    required this.onMonthChange,
    super.key,
  });

  final DateTime displayedMonth;
  final ValueChanged<DateTime> onMonthChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
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
          IconButton(
            icon: Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textPrimary,
              size: 26.sp,
            ),
            onPressed: () => onMonthChange(
              DateTime(displayedMonth.year, displayedMonth.month - 1),
            ),
            tooltip: 'Previous month',
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(displayedMonth),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textPrimary,
              size: 26.sp,
            ),
            onPressed: () => onMonthChange(
              DateTime(displayedMonth.year, displayedMonth.month + 1),
            ),
            tooltip: 'Next month',
          ),
        ],
      ),
    );
  }
}
