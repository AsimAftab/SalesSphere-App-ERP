import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Navigation header for picking and displaying a selected day (`Daily` targets).
class DayNavHeader extends StatelessWidget {
  const DayNavHeader({
    required this.displayedDate,
    required this.onDateChange,
    this.showCard = true,
    super.key,
  });

  final DateTime displayedDate;
  final ValueChanged<DateTime> onDateChange;
  final bool showCard;

  bool get _isToday {
    final now = DateTime.now();
    return displayedDate.year == now.year &&
        displayedDate.month == now.month &&
        displayedDate.day == now.day;
  }

  String get _dateLabel {
    final formatted = DateFormat('dd MMM yyyy').format(displayedDate);
    return _isToday ? 'Today • $formatted' : formatted;
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: displayedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateChange(picked);
    }
  }

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
          onPressed: () => onDateChange(
            displayedDate.subtract(const Duration(days: 1)),
          ),
          tooltip: 'Previous day',
        ),
        Expanded(
          child: InkWell(
            onTap: () => _pickDate(context),
            borderRadius: BorderRadius.circular(8.r),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16.sp,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    _dateLabel,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
          onPressed: () => onDateChange(
            displayedDate.add(const Duration(days: 1)),
          ),
          tooltip: 'Next day',
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
