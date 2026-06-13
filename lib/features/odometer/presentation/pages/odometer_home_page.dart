import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/providers/odometer_providers.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/widgets/start_trip_sheet.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/widgets/stop_trip_sheet.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:sales_sphere_erp/shared/widgets/today_status_card.dart';
import 'package:sales_sphere_erp/shared/widgets/summary_stats_card.dart';

class OdometerHomePage extends ConsumerWidget {
  const OdometerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTrip = ref.watch(activeTripProvider);
    final completedTrips = ref.watch(completedTripsProvider);
    
    int totalDistance = 0;
    for (final t in completedTrips) {
      if (t.distanceTravelled != null) {
        totalDistance += t.distanceTravelled!;
      }
    }

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
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
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
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Today's Status
              TodayStatusCard(
                icon: Icons.schedule_rounded,
                title: "Today's Status",
                statusBadge: activeTrip != null
                    ? const StatusBadge(label: 'On Trip', color: AppColors.blue500)
                    : completedTrips.isNotEmpty
                        ? const StatusBadge(label: 'Completed', color: AppColors.green500)
                        : const StatusBadge(label: 'Not Started', color: AppColors.textSecondary),
              ),

              if (activeTrip != null) ...[
                SizedBox(height: 16.h),
                // Active Trip Card
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.red500.withValues(alpha: 0.05),
                        blurRadius: 20.r,
                        spreadRadius: 2.r,
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: AppColors.red500.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.directions_car_rounded, color: AppColors.red500, size: 20.sp),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trip #${completedTrips.length + 1}',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Currently Active',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 12.w,
                            height: 12.h,
                            decoration: const BoxDecoration(
                              color: AppColors.red500,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      CustomButton(
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => StopTripSheet(trip: activeTrip),
                          );
                        },
                        label: 'Stop Trip ->',
                        backgroundColor: AppColors.red500,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(height: 24.h),
                CustomButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const StartTripSheet(),
                    );
                  },
                  label: 'Start New Trip',
                ),
              ],

              SizedBox(height: 32.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timeline_rounded, color: AppColors.blue500, size: 20.sp),
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
                    '${completedTrips.length} / ${completedTrips.length + (activeTrip != null ? 1 : 0)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              
              if (activeTrip == null && completedTrips.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 32.h),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.directions_car_outlined, color: AppColors.textHint, size: 48.sp),
                      SizedBox(height: 16.h),
                      Text(
                        'No trips recorded today',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _TripsCarousel(
                  completedTrips: completedTrips,
                  activeTrip: activeTrip,
                ),

              SizedBox(height: 24.h),
              // Monthly Summary
              SummaryStatsCard(
                title: 'Monthly Summary',
                icon: Icons.bar_chart_rounded,
                iconColor: AppColors.blue500,
                crossAxisCount: 2,
                onViewDetails: () {},
                stats: [
                  SummaryStatTile(
                    value: '${completedTrips.length}',
                    label: 'Total Trips',
                  ),
                  SummaryStatTile(
                    value: '$totalDistance KM',
                    label: 'Total Distance',
                  ),
                ],
              ),
              SizedBox(height: 40.h),
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
class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.index});

  final OdometerTrip trip;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isActive = trip.status == TripStatus.active;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trip $index',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isActive)
                const StatusBadge(label: 'Active', color: AppColors.blue500)
              else
                const StatusBadge(label: 'Completed', color: AppColors.green500),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.blue500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Reading',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${trip.startReading}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        trip.distanceUnit.label,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.red500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stop Reading',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        isActive ? '---' : '${trip.stopReading}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        trip.distanceUnit.label,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.green500.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distance Travelled',
                  style: TextStyle(
                    color: AppColors.green500,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isActive ? '... ${trip.distanceUnit.label}' : '${trip.distanceTravelled} ${trip.distanceUnit.label}',
                  style: TextStyle(
                    color: AppColors.green500,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripsCarousel extends StatefulWidget {
  const _TripsCarousel({
    required this.completedTrips,
    this.activeTrip,
  });

  final List<OdometerTrip> completedTrips;
  final OdometerTrip? activeTrip;

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
    final totalItems = widget.completedTrips.length + (widget.activeTrip != null ? 1 : 0);

    return Column(
      children: [
        SizedBox(
          height: 230.h,
          child: PageView.builder(
            controller: _controller,
            clipBehavior: Clip.none,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemCount: totalItems,
            itemBuilder: (context, index) {
              final trip = widget.activeTrip != null
                  ? (index == 0 ? widget.activeTrip! : widget.completedTrips[index - 1])
                  : widget.completedTrips[index];
                  
              final tripNumber = widget.activeTrip != null
                  ? (index == 0 ? totalItems : index)
                  : index + 1;

              return _TripCard(trip: trip, index: tripNumber);
            },
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            totalItems,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              width: _currentIndex == index ? 24.w : 8.w,
              height: 8.h,
              decoration: BoxDecoration(
                color: _currentIndex == index ? AppColors.blue500 : AppColors.border,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
