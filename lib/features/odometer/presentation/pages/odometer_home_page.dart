import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/auth/permissions.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_today_status.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_monthly_report.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_today_status.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/odometer_formatting.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/providers/odometer_providers.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/widgets/start_trip_sheet.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/widgets/stop_trip_sheet.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/widgets/trip_card.dart';
import 'package:sales_sphere_erp/shared/widgets/check_in_required_dialog.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:sales_sphere_erp/shared/widgets/summary_stats_card.dart';
import 'package:sales_sphere_erp/shared/widgets/today_status_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

class OdometerHomePage extends ConsumerWidget {
  const OdometerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayAsync = ref.watch(odometerTodayStatusProvider);
    final summary =
        ref
            .watch(odometerMonthlyReportProvider(now.year, now.month))
            .value
            ?.summary ??
        OdometerMonthlySummary.empty;
    final canRecord = ref.watch(
      hasPermissionProvider(Permissions.odometerRecord),
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
                          'Odometer',
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
                  SizedBox(height: 18.h),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref
                          ..invalidate(odometerTodayStatusProvider)
                          ..invalidate(
                            odometerMonthlyReportProvider(now.year, now.month),
                          );
                        await ref.read(odometerTodayStatusProvider.future);
                      },
                      child: todayAsync.when(
                        loading: () => const _HomeSkeleton(),
                        error: (_, __) => _ScrollableCenter(
                          child: _ErrorRetry(
                            onRetry: () =>
                                ref.invalidate(odometerTodayStatusProvider),
                          ),
                        ),
                        data: (status) => _Content(
                          status: status,
                          summary: summary,
                          canRecord: canRecord,
                        ),
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

class _Content extends StatelessWidget {
  const _Content({
    required this.status,
    required this.summary,
    required this.canRecord,
  });

  final OdometerTodayStatus status;
  final OdometerMonthlySummary summary;
  final bool canRecord;

  @override
  Widget build(BuildContext context) {
    final activeTrip = status.activeTrip;
    final completedTrips = status.completedTrips;
    // Show the active trip first (it's the current activity), then the
    // completed trips in trip-number order.
    final ordered = <OdometerTrip>[
      if (activeTrip != null) activeTrip,
      ...completedTrips,
    ];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TodayStatusCard(
            icon: Icons.schedule_rounded,
            title: "Today's Status",
            statusBadge: activeTrip != null
                ? const StatusBadge(label: 'On Trip', color: AppColors.blue500)
                : completedTrips.isNotEmpty
                ? const StatusBadge(
                    label: 'Completed',
                    color: AppColors.green500,
                  )
                : const StatusBadge(
                    label: 'Not Started',
                    color: AppColors.textSecondary,
                  ),
          ),
          if (activeTrip != null) ...[
            if (canRecord) ...[
              SizedBox(height: 16.h),
              // Status lives in the Today's Status card and the carousel below —
              // this is just the action.
              CustomButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => StopTripSheet(trip: activeTrip),
                ),
                label: 'Stop Trip ->',
                backgroundColor: AppColors.red500,
              ),
            ],
          ] else if (canRecord) ...[
            SizedBox(height: 24.h),
            const _StartTripButton(),
          ],
          SizedBox(height: 32.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timeline_rounded,
                    color: AppColors.blue500,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    "Today's Trips",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                '${completedTrips.length} / ${ordered.length}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (ordered.isEmpty)
            // Same empty-state copy, but housed in a white card so it sits in
            // line with the surrounding cards instead of floating on the
            // background.
            SectionCard(
              padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 24.w),
              children: const <Widget>[
                EmptyStateView(
                  icon: Icons.directions_car_outlined,
                  title: 'No trips today',
                  message: 'Start a trip to see it here.',
                ),
              ],
            )
          else
            _TripsCarousel(trips: ordered),
          SizedBox(height: 24.h),
          SummaryStatsCard(
            title: 'Monthly Summary',
            icon: Icons.bar_chart_rounded,
            crossAxisCount: 2,
            onViewDetails: () => context.pushNamed(Routes.odometerHistoryName),
            stats: [
              SummaryStatTile(
                value: '${summary.totalTrips}',
                label: 'Total Trips',
              ),
              SummaryStatTile(
                value:
                    '${formatReading(summary.totalDistance)} ${summary.distanceUnit.toUpperCase()}',
                label: 'Total Distance',
              ),
            ],
          ),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }
}

/// "Start New Trip" with an attendance gate. The backend rejects a trip start
/// with `422 NOT_CHECKED_IN` when the rep hasn't checked in — but the trip
/// form asks for a reading + photo first, so submitting only to be rejected
/// wastes that effort. This resolves today's attendance up front and, when the
/// rep isn't checked in, prompts them to check in instead of opening the form.
///
/// If attendance can't be resolved (offline / error) it opens the form anyway
/// and lets the server's gate (handled in [StartTripSheet]) be the backstop.
class _StartTripButton extends ConsumerStatefulWidget {
  const _StartTripButton();

  @override
  ConsumerState<_StartTripButton> createState() => _StartTripButtonState();
}

class _StartTripButtonState extends ConsumerState<_StartTripButton> {
  bool _checking = false;

  Future<void> _onPressed() async {
    setState(() => _checking = true);
    bool checkedIn;
    try {
      final status = await ref.read(attendanceTodayStatusProvider.future);
      checkedIn = status.isCheckedIn;
    } on Exception {
      // Couldn't resolve attendance — don't hard-block. Fall through and let
      // the server's NOT_CHECKED_IN gate (handled in the sheet) decide.
      checkedIn = true;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (!mounted) return;

    if (checkedIn) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const StartTripSheet(),
      );
      return;
    }

    final goToCheckIn = await CheckInRequiredDialog.show(
      context,
      message: 'You must check in before starting a trip.',
    );
    if ((goToCheckIn ?? false) && mounted) {
      unawaited(context.push(Routes.attendance));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      onPressed: _onPressed,
      isLoading: _checking,
      label: 'Start New Trip',
    );
  }
}

class _TripsCarousel extends StatefulWidget {
  const _TripsCarousel({required this.trips});

  final List<OdometerTrip> trips;

  @override
  State<_TripsCarousel> createState() => _TripsCarouselState();
}

class _TripsCarouselState extends State<_TripsCarousel> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trips = widget.trips;
    return Column(
      children: [
        SizedBox(
          height: 152.h,
          child: PageView.builder(
            controller: _controller,
            clipBehavior: Clip.none,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return OdometerTripCard(
                trip: trip,
                // A carousel card is one specific trip → open it directly
                // (focused single view), not the day-grouped tabs/list.
                onTap: () => context.pushNamed(
                  Routes.odometerTripDetailName,
                  pathParameters: <String, String>{'id': trip.id},
                  queryParameters: <String, String>{'focus': '1'},
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            trips.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              width: _currentIndex == index ? 24.w : 8.w,
              height: 8.h,
              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? AppColors.blue500
                    : AppColors.border,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shimmer placeholders shown while today's status loads.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Bone(
              width: double.infinity,
              height: 64.h,
              borderRadius: BorderRadius.circular(16.r),
            ),
            SizedBox(height: 16.h),
            Bone(
              width: double.infinity,
              height: 48.h,
              borderRadius: BorderRadius.circular(16.r),
            ),
            SizedBox(height: 32.h),
            Bone(
              width: 140.w,
              height: 16.h,
              borderRadius: BorderRadius.circular(4.r),
            ),
            SizedBox(height: 16.h),
            Bone(
              width: double.infinity,
              height: 152.h,
              borderRadius: BorderRadius.circular(16.r),
            ),
            SizedBox(height: 24.h),
            Bone(
              width: double.infinity,
              height: 170.h,
              borderRadius: BorderRadius.circular(16.r),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scrollable wrapper so loading/error states still trigger the pull-to-refresh.
class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(padding: EdgeInsets.all(32.w), child: child),
          ),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off_rounded, color: AppColors.textHint, size: 48.sp),
        SizedBox(height: 16.h),
        Text(
          "Couldn't load your trips",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 16.h),
        OutlinedCustomButton(onPressed: onRetry, label: 'Retry'),
      ],
    );
  }
}
