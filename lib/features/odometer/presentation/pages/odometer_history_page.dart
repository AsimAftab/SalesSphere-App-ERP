import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/month_nav_header.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_monthly_report.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/odometer_formatting.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/providers/odometer_providers.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/widgets/trip_card.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

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
    final reportAsync =
        ref.watch(odometerMonthlyReportProvider(_month.year, _month.month));

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: AppColors.textPrimary, size: 20.sp),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Odometer History',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
              child: MonthNavHeader(
                displayedMonth: _month,
                onMonthChange: (m) => setState(() => _month = m),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(
                    odometerMonthlyReportProvider(_month.year, _month.month),
                  );
                  await ref.read(
                    odometerMonthlyReportProvider(_month.year, _month.month)
                        .future,
                  );
                },
                child: reportAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _ErrorRetry(
                    onRetry: () => ref.invalidate(
                      odometerMonthlyReportProvider(
                          _month.year, _month.month),
                    ),
                  ),
                  data: (report) => _HistoryList(report: report),
                ),
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
      itemCount: days.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _MonthSummaryBar(summary: report.summary),
          );
        }
        final day = days[index - 1];
        final trips = byDay[day]!..sort((a, b) => a.tripNumber.compareTo(b.tripNumber));
        return _DaySection(day: day, trips: trips);
      },
    );
  }
}

class _MonthSummaryBar extends StatelessWidget {
  const _MonthSummaryBar({required this.summary});

  final OdometerMonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final unit = summary.distanceUnit.toUpperCase();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(value: '${summary.totalTrips}', label: 'Trips'),
          _divider(),
          _Stat(
            value: '${formatReading(summary.totalDistance)} $unit',
            label: 'Distance',
          ),
          _divider(),
          _Stat(
            value: '${summary.avgDistancePerTrip} $unit',
            label: 'Avg/Trip',
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 32.h, color: AppColors.border);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day, required this.trips});

  final DateTime day;
  final List<OdometerTrip> trips;

  @override
  Widget build(BuildContext context) {
    var total = 0.0;
    for (final t in trips) {
      total += t.distance ?? 0;
    }
    final unitLabel = trips.isEmpty ? '' : trips.first.distanceUnit.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEE, d MMM').format(day),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${trips.length} ${trips.length == 1 ? 'trip' : 'trips'} · '
                '${formatReading(total)} $unitLabel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        for (final trip in trips)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: OdometerTripCard(
              trip: trip,
              onTap: () => context.pushNamed(
                Routes.odometerTripDetailName,
                pathParameters: <String, String>{'id': trip.id},
              ),
            ),
          ),
      ],
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
        Icon(Icons.directions_car_outlined,
            color: AppColors.textHint, size: 56.sp),
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
