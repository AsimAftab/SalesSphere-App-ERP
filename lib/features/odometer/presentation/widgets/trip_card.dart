import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/odometer_formatting.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';

/// Card summarising one trip: a "Trip N" title + status over a Start / Stop /
/// Distance strip. Mirrors the unplanned-visit summary card so the two
/// field-ops features share one premium, consistent card. Used on the home
/// carousel and the busy-day detail list.
class OdometerTripCard extends StatelessWidget {
  const OdometerTripCard({required this.trip, this.onTap, super.key});

  final OdometerTrip trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = trip.isInProgress;

    final card = Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── Title + status ───────────────────────────────────────────
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Trip ${trip.tripNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              StatusBadge(
                label: isActive ? 'On Trip' : 'Completed',
                color: isActive ? AppColors.blue500 : AppColors.green500,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // ── Start / Stop / Distance ──────────────────────────────────
          _ReadingsStrip(trip: trip, isActive: isActive),
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

/// Start / Stop / Distance figures in a soft strip — the odometer analog of
/// the visit times strip. An active trip shows "—" for the stop reading and
/// distance (not yet known).
class _ReadingsStrip extends StatelessWidget {
  const _ReadingsStrip({required this.trip, required this.isActive});

  final OdometerTrip trip;
  final bool isActive;

  String _reading(double? value) => value == null
      ? '—'
      : '${formatReading(value)} ${trip.distanceUnit.label}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          _StatColumn(
            icon: Icons.play_circle_outline_rounded,
            label: 'Start',
            value: _reading(trip.startReading),
          ),
          _divider(),
          _StatColumn(
            icon: Icons.stop_circle_outlined,
            label: 'Stop',
            value: isActive ? '—' : _reading(trip.stopReading),
          ),
          _divider(),
          _StatColumn(
            icon: Icons.straighten_rounded,
            label: 'Distance',
            value: isActive ? '—' : _reading(trip.distance),
            valueColor: AppColors.primary,
            iconColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1.w, height: 32.h, color: AppColors.border);
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 14.sp,
                color: iconColor ?? AppColors.textSecondary,
              ),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            // Long readings (high-mileage odometers) auto-shrink to fit the
            // column instead of truncating; short ones stay at 14.sp.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
