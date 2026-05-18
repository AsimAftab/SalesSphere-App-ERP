import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Chevron-left / month label / chevron-right row used by both the
/// home page calendar and the details list page. Pass `showCard: true`
/// (default) for the white rounded container shown on the details page;
/// pass `showCard: false` when this widget is rendered inside the
/// calendar card so the chrome doesn't double up.
class MonthNavHeader extends StatelessWidget {
  const MonthNavHeader({
    required this.displayedMonth,
    required this.onMonthChange,
    this.showCard = true,
    super.key,
  });

  final DateTime displayedMonth;
  final ValueChanged<DateTime> onMonthChange;

  /// Wrap the row in the standalone surface card. Set to false when
  /// the parent already provides a card surface around this widget.
  final bool showCard;

  @override
  Widget build(BuildContext context) {
    final row = Row(
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
                fontWeight: FontWeight.w600,
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
    );

    if (!showCard) return row;

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
      child: row,
    );
  }
}
