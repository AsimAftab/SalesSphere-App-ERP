import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';

class TrackingStatusCard extends StatelessWidget {
  final String duration;
  final int queuedCount;
  final bool isConnected;

  const TrackingStatusCard({
    super.key,
    required this.duration,
    required this.queuedCount,
    this.isConnected = true,
  });

  @override
  Widget build(BuildContext context) {
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
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.02),
            blurRadius: 8.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Elegant Header ──
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isConnected) ...[
                      // Pulsing Dot
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.4),
                              blurRadius: 4.r,
                              spreadRadius: 2.r,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],
                    Text(
                      'Tracking Active',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  'Recording your location in real time',
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

          // ── Body Section ──
          Container(
            color: isConnected 
                ? AppColors.success.withValues(alpha: 0.2) 
                : AppColors.warning.withValues(alpha: 0.2),
            padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 24.h),
            child: Column(
              children: [
                // ── Dashboard Metrics Card ──
                Container(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10.r,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Duration
                      Expanded(
                        child: _buildMetricColumn(
                          label: 'Duration',
                          value: duration,
                          icon: Icons.timer_outlined,
                          iconColor: AppColors.primary,
                        ),
                      ),
                      
                      // Separator
                      Container(
                        width: 1,
                        height: 48.h,
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                      
                      // Queued Data
                      Expanded(
                        child: _buildMetricColumn(
                          label: 'Queued Data',
                          value: '$queuedCount',
                          icon: Icons.cloud_upload_outlined,
                          iconColor: queuedCount > 0 ? AppColors.warning : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // ── Sleek Status Banner ──
                Container(
                  padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10.r,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: isConnected 
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.warning.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isConnected ? Icons.satellite_alt_rounded : Icons.sync_problem_rounded, 
                          color: isConnected ? AppColors.success : AppColors.warning, 
                          size: 16.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          isConnected 
                              ? 'Live streaming location updates to server.'
                              : 'Connecting to server... location data is in queue.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
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

  Widget _buildMetricColumn({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14.sp, color: iconColor),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
