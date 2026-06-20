import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/month_nav_header.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_monthly_report.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/odometer_formatting.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/providers/odometer_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

class OdometerHistoryPage extends ConsumerStatefulWidget {
  const OdometerHistoryPage({super.key});

  @override
  ConsumerState<OdometerHistoryPage> createState() =>
      _OdometerHistoryPageState();
}

class _OdometerHistoryPageState extends ConsumerState<OdometerHistoryPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(
      odometerMonthlyReportProvider(_month.year, _month.month),
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
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 4.h, 20.w, 0),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: AppColors.textPrimary,
                            size: 20.sp,
                          ),
                          onPressed: () => context.pop(),
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: 36.w,
                            minHeight: 36.h,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'Odometer History',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                    child: MonthNavHeader(
                      displayedMonth: _month,
                      onMonthChange: (m) => setState(() => _month = m),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(
                          odometerMonthlyReportProvider(
                            _month.year,
                            _month.month,
                          ),
                        );
                        await ref.read(
                          odometerMonthlyReportProvider(
                            _month.year,
                            _month.month,
                          ).future,
                        );
                      },
                      child: reportAsync.when(
                        loading: () => const _HistorySkeleton(),
                        error: (_, __) => _ErrorRetry(
                          onRetry: () => ref.invalidate(
                            odometerMonthlyReportProvider(
                              _month.year,
                              _month.month,
                            ),
                          ),
                        ),
                        data: (report) => _HistoryList(report: report),
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

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.report});

  final OdometerMonthlyReport report;

  @override
  Widget build(BuildContext context) {
    if (report.records.isEmpty) {
      return _EmptyMonth();
    }

    final byDay = <DateTime, List<OdometerTrip>>{};
    for (final t in report.records) {
      final raw = t.date ?? t.startedAt ?? t.createdAt;
      final key = raw == null
          ? DateTime(report.year, report.month)
          : DateTime(raw.year, raw.month, raw.day);
      byDay.putIfAbsent(key, () => <OdometerTrip>[]).add(t);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final trips = byDay[day]!
          ..sort((a, b) => a.tripNumber.compareTo(b.tripNumber));
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: _DayCard(day: day, trips: trips),
        );
      },
    );
  }
}

/// One card per calendar day. Shows the date, trip count and the day's
/// total distance — no odometer readings (those live on the detail page).
/// Tapping opens the day's trips in the tabbed detail view, focused on the
/// first trip.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.trips});

  final DateTime day;
  final List<OdometerTrip> trips;

  @override
  Widget build(BuildContext context) {
    var total = 0.0;
    for (final t in trips) {
      total += t.distance ?? 0;
    }
    final unitLabel = trips.isEmpty ? '' : trips.first.distanceUnit.label;
    final active = trips.where((t) => t.isInProgress).length;
    final completed = trips.length - active;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: () => context.pushNamed(
            Routes.odometerTripDetailName,
            pathParameters: <String, String>{'id': trips.first.id},
          ),
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: <Widget>[
                // Date chip — weekday over day-of-month.
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        DateFormat('EEE').format(day).toUpperCase(),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        DateFormat('d').format(day),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 14.w),
                // Relative day + a summary line (count · done · active).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _relativeDayLabel(day),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 10.w,
                        runSpacing: 4.h,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            '${trips.length} '
                            '${trips.length == 1 ? 'trip' : 'trips'}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _CountChip(
                            color: AppColors.green500,
                            label: '$completed done',
                          ),
                          if (active > 0)
                            _CountChip(
                              color: AppColors.blue500,
                              label: '$active active',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                // Day total distance + unit on one line (e.g. "9 km").
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      formatReading(total),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      unitLabel,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint,
                  size: 20.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder list shown while the month's report loads.
/// "Today" / "Yesterday" for recent days, otherwise "d MMM yyyy".
String _relativeDayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('d MMM yyyy').format(day);
}

/// A tiny status indicator: a coloured dot + label (e.g. "4 done").
class _CountChip extends StatelessWidget {
  const _CountChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7.w,
          height: 7.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 5.w),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: const _DayCardSkeleton(),
        ),
      ),
    );
  }
}

class _DayCardSkeleton extends StatelessWidget {
  const _DayCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: <Widget>[
          Bone(
            width: 48.w,
            height: 48.w,
            borderRadius: BorderRadius.circular(12.r),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Bone(
                  width: 130.w,
                  height: 14.h,
                  borderRadius: BorderRadius.circular(4.r),
                ),
                SizedBox(height: 8.h),
                Bone(
                  width: 64.w,
                  height: 12.h,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Bone(
            width: 52.w,
            height: 18.h,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ],
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 120.h),
        Icon(
          Icons.directions_car_outlined,
          color: AppColors.textHint,
          size: 56.sp,
        ),
        SizedBox(height: 16.h),
        Center(
          child: Text(
            'No trips this month',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 120.h),
        Icon(Icons.cloud_off_rounded, color: AppColors.textHint, size: 48.sp),
        SizedBox(height: 16.h),
        Center(
          child: Text(
            "Couldn't load this month",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 80.w),
          child: OutlinedCustomButton(onPressed: onRetry, label: 'Retry'),
        ),
      ],
    );
  }
}
