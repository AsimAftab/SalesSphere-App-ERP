import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/attendance_calendar.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/check_in_out_button.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/monthly_summary_card.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/today_status_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// `/attendance` — home surface for the Attendance feature, reached
/// from the More tab. Owns the currently displayed month and the
/// selected day so the calendar, the today status card, the
/// check-in/out button, and the monthly summary all read from the
/// same source.
class AttendanceHomePage extends ConsumerStatefulWidget {
  const AttendanceHomePage({super.key});

  @override
  ConsumerState<AttendanceHomePage> createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends ConsumerState<AttendanceHomePage> {
  late DateTime _displayedMonth;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  /// Day-of-month → status, derived from the watched month's record
  /// list so the calendar can paint dots without re-iterating.
  Map<int, AttendanceStatus> _statusByDay(List<AttendanceRecord> records) {
    final out = <int, AttendanceStatus>{};
    for (final r in records) {
      if (r.date.year == _displayedMonth.year &&
          r.date.month == _displayedMonth.month) {
        out[r.date.day] = r.status;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final monthAsync = ref.watch(
      attendanceMonthProvider(_displayedMonth.year, _displayedMonth.month),
    );
    final todayAsync = ref.watch(todayAttendanceProvider);
    final summary = ref.watch(
      attendanceMonthlySummaryProvider(
        _displayedMonth.year,
        _displayedMonth.month,
      ),
    );

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SvgPicture.asset(
                'assets/images/corner_bubble.svg',
                fit: BoxFit.cover,
                height: 180.h,
              ),
            ),
            SafeArea(
              // Header is pinned at the top of the SafeArea — the
              // scrolling content sits inside an Expanded below it so
              // the back button + "Attendance" stay visible regardless
              // of scroll offset.
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
                    child: _AppBar(onBack: _back),
                  ),
                  SizedBox(height: 18.h),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TodayStatusCard(today: todayAsync.value),
                          SizedBox(height: 18.h),
                          const CheckInOutButton(),
                          SizedBox(height: 22.h),
                          _CalendarCard(
                            child: AttendanceCalendar(
                              displayedMonth: _displayedMonth,
                              selected: _selected,
                              statusByDay: _statusByDay(
                                monthAsync.value ?? const <AttendanceRecord>[],
                              ),
                              onSelect: (date) {
                                setState(() => _selected = date);
                                context.push(
                                  Routes.attendanceDayDetailPath(
                                    date.toIso8601String().split('T').first,
                                  ),
                                );
                              },
                              onMonthChange: (next) =>
                                  setState(() => _displayedMonth = next),
                            ),
                          ),
                          SizedBox(height: 18.h),
                          const _LegendRow(),
                          SizedBox(height: 22.h),
                          MonthlySummaryCard(summary: summary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.textdark,
            size: 20.sp,
          ),
          onPressed: onBack,
          tooltip: 'Back',
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
        ),
        SizedBox(width: 12.w),
        Text(
          'Attendance',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 16.h, 8.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Five colour-coded chips that decode the calendar's status dots.
/// Inlined here rather than living in its own file because it's
/// home-page-specific chrome — the legend has no other consumer.
///
/// Two explicit rows so the chips line up cleanly across screen sizes:
/// row 1 stacks Present / Absent / Half-Day, row 2 stacks Leave /
/// Weekly Off. A `Wrap` would let chip widths drift the row break
/// around as the device width changes; fixing the layout reads more
/// deliberate.
class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Expanded(child: _LegendChip(status: AttendanceStatus.present)),
            Expanded(child: _LegendChip(status: AttendanceStatus.absent)),
            Expanded(child: _LegendChip(status: AttendanceStatus.halfDay)),
          ],
        ),
        SizedBox(height: 8.h),
        const Row(
          children: <Widget>[
            Expanded(child: _LegendChip(status: AttendanceStatus.leave)),
            Expanded(child: _LegendChip(status: AttendanceStatus.weeklyOff)),
            // Empty third slot keeps row-2 chips left-aligned with row 1
            // instead of stretching across the full width.
            Spacer(),
          ],
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final p = status.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10.r,
          height: 10.r,
          decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
        ),
        SizedBox(width: 8.w),
        Text(
          p.label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
