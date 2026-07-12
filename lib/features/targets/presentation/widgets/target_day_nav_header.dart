import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Chevron-left / day label / chevron-right row driving the `?date=` query
/// param on `/targets/me`. Same chrome as the attendance `MonthNavHeader`,
/// but day-granular because the endpoint takes a single day (DAILY targets
/// are scored for it, MONTHLY for the month containing it).
///
/// [selectedDate] == null means "today" — the default state that sends no
/// date param so the server resolves today in the org's timezone. The right
/// chevron is disabled at today and the picker forbids the future: a future
/// day has no actuals by definition and would render as misleading zeros.
class TargetDayNavHeader extends StatelessWidget {
  const TargetDayNavHeader({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectDate,
    super.key,
  });

  /// Null = today (org-timezone default).
  final DateTime? selectedDate;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelectDate;

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) onSelectDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final isToday = selectedDate == null;
    final label = isToday
        ? 'Today'
        : DateFormat('EEE, d MMM yyyy').format(selectedDate!);

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
            onPressed: onPrevious,
            tooltip: 'Previous day',
          ),
          Expanded(
            child: Center(
              child: InkWell(
                onTap: () => _pickDate(context),
                borderRadius: BorderRadius.circular(8.r),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.textSecondary,
                        size: 14.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        label,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: isToday ? AppColors.textSecondary : AppColors.textPrimary,
              size: 26.sp,
            ),
            // Disabled at today — the future has no actuals to show.
            onPressed: isToday ? null : onNext,
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}
