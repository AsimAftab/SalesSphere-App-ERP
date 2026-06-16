import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/odometer_formatting.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';

/// Card summarising one trip: start/stop readings + distance, with an
/// active/completed badge. Used on the home carousel and the history list.
class OdometerTripCard extends StatelessWidget {
  const OdometerTripCard({required this.trip, this.onTap, super.key});

  final OdometerTrip trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = trip.isInProgress;
    final unit = trip.distanceUnit.label;

    final card = Container(
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
                'Trip ${trip.tripNumber}',
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
                child: _ReadingBox(
                  label: 'Start Reading',
                  value: formatReading(trip.startReading),
                  unit: unit,
                  color: AppColors.blue500,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _ReadingBox(
                  label: 'Stop Reading',
                  value: isActive ? '---' : formatReading(trip.stopReading),
                  unit: unit,
                  color: AppColors.red500,
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
                  isActive
                      ? '... $unit'
                      : '${formatReading(trip.distance)} $unit',
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

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: card,
    );
  }
}

class _ReadingBox extends StatelessWidget {
  const _ReadingBox({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
