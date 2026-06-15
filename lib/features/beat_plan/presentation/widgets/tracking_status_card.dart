import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Live tracking status + controls. Driven by the background service's pushed
/// state (duration, distance, queued-ping count, connection) with Pause/Resume
/// + Stop controls that mirror the persistent notification.
class TrackingStatusCard extends StatelessWidget {
  const TrackingStatusCard({
    required this.duration,
    required this.distanceKm,
    required this.queuedCount,
    required this.isConnected,
    required this.isPaused,
    this.batteryLevel,
    super.key,
  });

  final String duration;
  final double distanceKm;
  final int queuedCount;
  final bool isConnected;
  final bool isPaused;

  /// Device battery % (0–100). Null hides the battery metric.
  final int? batteryLevel;

  @override
  Widget build(BuildContext context) {
    final accent = isPaused
        ? AppColors.warning
        : (isConnected ? AppColors.success : AppColors.warning);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 24.r,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
            child: Row(
              children: [
                Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 4.r,
                        spreadRadius: 2.r,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaused ? 'Tracking paused' : 'Tracking active',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        isConnected
                            ? 'Streaming your location in real time'
                            : 'Offline — buffering until reconnected',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  isConnected
                      ? Icons.satellite_alt_rounded
                      : Icons.sync_problem_rounded,
                  color: accent,
                  size: 20.sp,
                ),
              ],
            ),
          ),
          Container(
            color: accent.withValues(alpha: 0.12),
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 20.h),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _metric(
                          'Duration',
                          duration,
                          Icons.timer_outlined,
                          AppColors.primary,
                        ),
                      ),
                      _divider(),
                      Expanded(
                        child: _metric(
                          'Distance',
                          '${distanceKm.toStringAsFixed(2)} km',
                          Icons.route_outlined,
                          AppColors.secondary,
                        ),
                      ),
                      _divider(),
                      Expanded(
                        child: _metric(
                          'Queued',
                          '$queuedCount',
                          Icons.cloud_upload_outlined,
                          queuedCount > 0 ? AppColors.warning : AppColors.success,
                        ),
                      ),
                      if (batteryLevel != null) ...[
                        _divider(),
                        Expanded(
                          child: _metric(
                            'Battery',
                            '$batteryLevel%',
                            _batteryIcon(batteryLevel!),
                            _batteryColor(batteryLevel!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40.h,
        color: AppColors.border.withValues(alpha: 0.5),
      );

  Color _batteryColor(int level) {
    if (level <= 20) return AppColors.error;
    if (level <= 50) return AppColors.warning;
    return AppColors.success;
  }

  IconData _batteryIcon(int level) {
    if (level <= 20) return Icons.battery_alert_rounded;
    if (level <= 60) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14.sp, color: color),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
