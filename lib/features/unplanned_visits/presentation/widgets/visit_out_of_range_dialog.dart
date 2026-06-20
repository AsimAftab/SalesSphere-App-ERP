import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/utils/geo_distance.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Modal shown when starting an unplanned visit is blocked because the rep is
/// outside the target's geofence. Surfaces the measured distance, the required
/// radius and the target's name so they know how far to move.
///
/// Mirrors the attendance `OutsideGeofenceDialog` styling (orange warning
/// header) so the geofence experience reads consistently across the app — a
/// dialog, not a transient snackbar.
class VisitOutOfRangeDialog extends StatelessWidget {
  const VisitOutOfRangeDialog({
    required this.distanceMeters,
    required this.radiusMeters,
    required this.targetName,
    this.targetAddress,
    super.key,
  });

  /// How far the rep currently is from the target anchor.
  final double distanceMeters;

  /// The geofence radius they must be within.
  final double radiusMeters;

  /// The entity being visited (customer / prospect / site) name.
  final String targetName;

  /// The target's address, shown for context when available.
  final String? targetAddress;

  static Future<void> show(
    BuildContext context, {
    required double distanceMeters,
    required double radiusMeters,
    required String targetName,
    String? targetAddress,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => VisitOutOfRangeDialog(
        distanceMeters: distanceMeters,
        radiusMeters: radiusMeters,
        targetName: targetName,
        targetAddress: targetAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14.sp,
      height: 1.5,
    );
    final bold = base.copyWith(fontWeight: FontWeight.w700);
    final address = targetAddress;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── Orange header ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.warning.withValues(alpha: 0.10),
            padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64.r,
                  height: 64.r,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.location_off_rounded,
                    color: AppColors.warning,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Outside Visit Range',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    style: base,
                    children: <InlineSpan>[
                      const TextSpan(text: "You're "),
                      TextSpan(
                        text: formatDistanceMeters(distanceMeters),
                        style: bold,
                      ),
                      const TextSpan(text: ' from '),
                      TextSpan(text: targetName, style: bold),
                      const TextSpan(text: '. Move within '),
                      TextSpan(text: '${radiusMeters.round()} m', style: bold),
                      const TextSpan(text: ' of it to start the visit.'),
                    ],
                  ),
                  textAlign: TextAlign.left,
                ),
                if (address != null && address.isNotEmpty) ...<Widget>[
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.location_on_outlined,
                          size: 15.sp,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.sp,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 24.h),
                PrimaryButton(
                  label: 'OK',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
