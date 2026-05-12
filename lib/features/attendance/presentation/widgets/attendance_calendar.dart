import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';

/// Stateless 6×7 month grid with a status dot under each in-month day.
/// Parent owns `displayedMonth` and `selected` so the same state can
/// also drive the `attendanceMonthProvider` family key — there is no
/// "calendar's idea of the month" vs "page's idea of the month" to keep
/// in sync.
class AttendanceCalendar extends StatelessWidget {
  const AttendanceCalendar({
    required this.displayedMonth,
    required this.selected,
    required this.statusByDay,
    required this.onSelect,
    required this.onMonthChange,
    super.key,
  });

  /// Any DateTime in the target month — only `year` and `month` are
  /// read.
  final DateTime displayedMonth;

  /// The currently picked day. Midnight-normalized. Rendered with the
  /// filled navy selection circle.
  final DateTime selected;

  /// `day-of-month → status`. Days absent from the map render without
  /// a dot. The map is derived once by the parent from the watched
  /// month's record list.
  final Map<int, AttendanceStatus> statusByDay;

  /// Fired when a user taps a day cell. The argument is a fresh
  /// `DateTime` at midnight for that day.
  final ValueChanged<DateTime> onSelect;

  /// Fired when the user advances/rewinds the visible month. The
  /// argument is a fresh `DateTime(year, month, 1)` for the new month.
  final ValueChanged<DateTime> onMonthChange;

  @override
  Widget build(BuildContext context) {
    final year = displayedMonth.year;
    final month = displayedMonth.month;
    final firstOfMonth = DateTime(year, month);
    final lastDay = DateTime(year, month + 1, 0).day;
    // `DateTime.weekday` is 1..7 with Mon=1, Sun=7. The calendar runs
    // Sunday-first, so shift so that Sun=0..Sat=6.
    final leadingOffset = firstOfMonth.weekday % 7;
    final today = DateTime.now();
    final isCurrentMonth = today.year == year && today.month == month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(
          displayedMonth: displayedMonth,
          onMonthChange: onMonthChange,
        ),
        SizedBox(height: 12.h),
        const _WeekdayRow(),
        SizedBox(height: 6.h),
        for (var row = 0; row < 6; row++)
          Row(
            children: <Widget>[
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _buildCell(
                    row: row,
                    col: col,
                    leadingOffset: leadingOffset,
                    lastDay: lastDay,
                    year: year,
                    month: month,
                    isCurrentMonth: isCurrentMonth,
                    todayDay: today.day,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCell({
    required int row,
    required int col,
    required int leadingOffset,
    required int lastDay,
    required int year,
    required int month,
    required bool isCurrentMonth,
    required int todayDay,
  }) {
    final cellIndex = row * 7 + col;
    final day = cellIndex - leadingOffset + 1;
    if (day < 1 || day > lastDay) {
      return SizedBox(height: 44.h);
    }
    final cellDate = DateTime(year, month, day);
    final isSelected = cellDate.year == selected.year &&
        cellDate.month == selected.month &&
        cellDate.day == selected.day;
    final isToday = isCurrentMonth && day == todayDay;
    final status = statusByDay[day];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(cellDate),
      child: SizedBox(
        height: 44.h,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 32.r,
              height: 32.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                // Today gets a thin outline when not already selected,
                // so it's still visually distinct on first paint.
                border: !isSelected && isToday
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      )
                    : null,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              width: 6.r,
              height: 6.r,
              decoration: BoxDecoration(
                color: status?.palette.accent ?? Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.displayedMonth, required this.onMonthChange});

  final DateTime displayedMonth;
  final ValueChanged<DateTime> onMonthChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: Icon(
            Icons.chevron_left_rounded,
            color: AppColors.textPrimary,
            size: 24.sp,
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
            size: 24.sp,
          ),
          onPressed: () => onMonthChange(
            DateTime(displayedMonth.year, displayedMonth.month + 1),
          ),
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    const labels = <String>['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Row(
      children: <Widget>[
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
