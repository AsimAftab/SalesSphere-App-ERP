import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Live, display-only tracking status pushed from the background location
/// service — elapsed duration, distance, queued-ping count, connection state
/// and battery. Tracking is system-controlled, so the card has no user
/// controls; the live dot pulses gently while streaming.
class TrackingStatusCard extends StatefulWidget {
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
  State<TrackingStatusCard> createState() => _TrackingStatusCardState();
}

class _TrackingStatusCardState extends State<TrackingStatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  /// Actively streaming — the only state that pulses.
  bool get _isLive => !widget.isPaused && widget.isConnected;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (_isLive) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(TrackingStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isLive && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_isLive && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isPaused
        ? AppColors.warning
        : (widget.isConnected ? AppColors.success : AppColors.warning);

    final IconData statusIcon;
    final String pillLabel;
    final String title;
    final String subtitle;
    if (widget.isPaused) {
      statusIcon = Icons.pause_rounded;
      pillLabel = 'PAUSED';
      title = 'Tracking paused';
      subtitle = 'Location updates are paused';
    } else if (widget.isConnected) {
      statusIcon = Icons.satellite_alt_rounded;
      pillLabel = 'LIVE';
      title = 'Tracking active';
      subtitle = 'Streaming your location in real time';
    } else {
      statusIcon = Icons.sync_problem_rounded;
      pillLabel = 'OFFLINE';
      title = 'Tracking active';
      subtitle = 'Offline — buffering until reconnected';
    }

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
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
            child: Row(
              children: [
                // Leading status icon-chip.
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: accent, size: 20.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
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
                SizedBox(width: 12.w),
                _StatusPill(label: pillLabel, accent: accent, pulse: _pulse, isLive: _isLive),
              ],
            ),
          ),
          Container(
            color: accent.withValues(alpha: 0.12),
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 18.h),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _metric(
                      'Duration',
                      widget.duration,
                      Icons.timer_outlined,
                      AppColors.primary,
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _metric(
                      'Distance',
                      '${widget.distanceKm.toStringAsFixed(2)} km',
                      Icons.route_outlined,
                      AppColors.secondary,
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _metric(
                      'Queued',
                      '${widget.queuedCount}',
                      Icons.cloud_upload_outlined,
                      widget.queuedCount > 0
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                  if (widget.batteryLevel != null) ...[
                    _divider(),
                    Expanded(
                      child: _metric(
                        'Battery',
                        '${widget.batteryLevel}%',
                        _batteryIcon(widget.batteryLevel!),
                        _batteryColor(widget.batteryLevel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 56.h,
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16.sp, color: color),
          ),
          SizedBox(height: 8.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            textAlign: TextAlign.center,
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
    );
  }
}

/// Accent status pill (LIVE / PAUSED / OFFLINE) with a leading dot that pulses
/// a soft glow while live.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.accent,
    required this.pulse,
    required this.isLive,
  });

  final String label;
  final Color accent;
  final Animation<double> pulse;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(40.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) {
              final t = isLive ? pulse.value : 0.0;
              return Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.2 + 0.4 * t),
                      blurRadius: 2.r + 4.r * t,
                      spreadRadius: 1.r + 3.r * t,
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
