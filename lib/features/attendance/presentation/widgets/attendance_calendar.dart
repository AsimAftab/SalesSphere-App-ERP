import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/month_nav_header.dart';

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
        MonthNavHeader(
          displayedMonth: displayedMonth,
          onMonthChange: onMonthChange,
          showCard: false,
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

    // Off-month days (trailing days of the previous month before the
    // 1st, and leading days of the next month after `lastDay`) render
    // in a muted color so the grid reads as a continuous calendar
    // rather than dropping rows of empty cells. They're not tappable
    // and never carry a status dot — that data belongs to the
    // displayed month only.
    if (day < 1) {
      // Trailing days of the previous month.
      final prevLast = DateTime(year, month, 0).day;
      final prevDay = prevLast + day; // `day` is <= 0 here
      return _OffMonthCell(label: '$prevDay');
    }
    if (day > lastDay) {
      // Leading days of the next month.
      final nextDay = day - lastDay;
      return _OffMonthCell(label: '$nextDay');
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

/// Faded numeric cell for days that belong to the previous or next
/// month. Non-interactive — taps fall through. Mirrors the in-month
/// cell's exact layout (32×32 number circle + 4h gap + 6×6 dot slot)
/// so day numbers line up across the row even though off-month cells
/// don't render a status dot.
class _OffMonthCell extends StatelessWidget {
  const _OffMonthCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.h,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 32.r,
            height: 32.r,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          // Empty placeholder occupies the same height as the in-month
          // dot so the row's vertical rhythm stays aligned.
          SizedBox(width: 6.r, height: 6.r),
        ],
      ),
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
