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
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/day_detail_card.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/month_nav_header.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_search_filter.dart';
import 'package:sales_sphere_erp/shared/widgets/refreshable_list.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// `/attendance/details` — month-list surface reached from the home
/// page's "View Details" button. Owns the displayed month and the
/// optional status filter; the underlying month query is shared with
/// the home page through `attendanceMonthProvider`.
class AttendanceDetailsPage extends ConsumerStatefulWidget {
  const AttendanceDetailsPage({super.key});

  @override
  ConsumerState<AttendanceDetailsPage> createState() =>
      _AttendanceDetailsPageState();
}

class _AttendanceDetailsPageState extends ConsumerState<AttendanceDetailsPage> {
  late DateTime _displayedMonth;

  /// `null` = All Days; otherwise the list is narrowed to records
  /// with the matching status.
  AttendanceStatus? _filter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
  }

  List<AttendanceRecord> _applyFilter(List<AttendanceRecord> source) {
    // Weekly-off rows aren't actionable on the details list — they're
    // shown on the home calendar's legend but the user never needs to
    // filter or open one. Strip them before any further filtering so
    // both the "All Days" view and any specific-status view stay
    // focused on real attendance days.
    final actionable = source
        .where((r) => r.status != AttendanceStatus.weeklyOff)
        .where((r) => _filter == null || r.status == _filter)
        .toList();
    // Most recent day first, so today's record sits at the top.
    actionable.sort((a, b) => b.date.compareTo(a.date));
    return actionable;
  }

  @override
  Widget build(BuildContext context) {
    final monthAsync = ref.watch(
      attendanceMonthProvider(_displayedMonth.year, _displayedMonth.month),
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
              child: Column(
                children: <Widget>[
                  _AppBar(onBack: () => context.pop()),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: MonthNavHeader(
                      displayedMonth: _displayedMonth,
                      onMonthChange: (next) =>
                          setState(() => _displayedMonth = next),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimarySearchFilter<AttendanceStatus?>(
                      selected: _filter,
                      onChanged: (next) => setState(() => _filter = next),
                      options: <SearchFilterOption<AttendanceStatus?>>[
                        const SearchFilterOption<AttendanceStatus?>(
                          value: null,
                          label: 'All Days',
                          icon: Icons.list_alt_rounded,
                        ),
                        // Weekly-off intentionally omitted — see
                        // `_applyFilter` for the matching list-side
                        // exclusion. The user never needs to drill
                        // into a weekend row.
                        for (final status in AttendanceStatus.values)
                          if (status != AttendanceStatus.weeklyOff)
                            SearchFilterOption<AttendanceStatus?>(
                              value: status,
                              label: status.palette.label,
                              icon: status.palette.icon,
                              iconColor: status.palette.accent,
                            ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Expanded(
                    child: RefreshableList<AttendanceRecord>(
                      async: monthAsync,
                      filter: _applyFilter,
                      onRefresh: () async {
                        ref.invalidate(
                          attendanceMonthProvider(
                            _displayedMonth.year,
                            _displayedMonth.month,
                          ),
                        );
                        await ref.read(
                          attendanceMonthProvider(
                            _displayedMonth.year,
                            _displayedMonth.month,
                          ).future,
                        );
                      },
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                      separator: SizedBox(height: 12.h),
                      itemBuilder: (context, record) => DayDetailCard(
                        record: record,
                        onTap: () => context.push(
                          Routes.attendanceDayDetailPath(
                            record.date.toIso8601String().split('T').first,
                          ),
                        ),
                      ),
                      skeletonItemBuilder: (_, __) =>
                          DayDetailCard(record: _placeholder, onTap: () {}),
                      emptyBuilder: (_) =>
                          _EmptyState(hasFilter: _filter != null),
                      errorBuilder: (_, __, ___) => const _ErrorState(),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textdark,
              size: 20.sp,
            ),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          SizedBox(width: 12.w),
          Text(
            'Attendance Details',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sample record fed to skeleton cards so Skeletonizer can paint a
/// realistic bone layout (status pill, two rows of mini-tiles).
final _placeholder = AttendanceRecord(
  id: '',
  date: DateTime(2026),
  status: AttendanceStatus.present,
  checkInAt: DateTime(2026, 1, 1, 9),
  checkOutAt: DateTime(2026, 1, 1, 18),
  checkInAddress: 'Loading address line',
);

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.event_note_outlined,
      title: hasFilter ? 'No matches' : 'No attendance yet',
      message: hasFilter
          ? 'No days match the current filter.'
          : 'No attendance logged for this month yet.',
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          "Couldn't load attendance. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}
