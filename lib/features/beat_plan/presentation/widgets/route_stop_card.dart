import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/geo_distance.dart';
import '../../../../shared/widgets/custom_button.dart';

class RouteStopCard extends StatelessWidget {
  final String name;
  final String ownerName;
  final String type;
  final String address;
  final String status;
  final String distance;
  final bool isActive;
  final String? startTime;
  final String? endTime;
  final String? timeSpent;
  final VoidCallback onTap;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenDirections;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onSkip;
  final bool isStarted;
  final String? notes;
  final String? photoUrl;
  final String? followUp;

  /// Geofence: distance in metres from the rep to this stop, or null when it
  /// can't be measured (no live position / stop has no location).
  final double? proximityMeters;

  /// Geofence gate: false disables Start (rep is out of range, or we don't
  /// yet have their position). Default true so non-geofenced contexts are
  /// unaffected.
  final bool canCheckIn;

  const RouteStopCard({
    super.key,
    required this.name,
    required this.ownerName,
    required this.type,
    required this.address,
    required this.status,
    required this.distance,
    this.isActive = false,
    this.startTime,
    this.endTime,
    this.timeSpent,
    required this.onTap,
    required this.onOpenMap,
    required this.onOpenDirections,
    required this.onStart,
    required this.onStop,
    required this.onSkip,
    this.isStarted = false,
    this.notes,
    this.photoUrl,
    this.followUp,
    this.proximityMeters,
    this.canCheckIn = true,
  });

  @override
  Widget build(BuildContext context) {
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isVisited = status.toLowerCase() == 'visited';
    final isPending = status.toLowerCase() == 'pending';
    
    Color statusColor;
    IconData statusIcon;
    
    if (isVisited) {
      statusColor = AppColors.success;
      statusIcon = Icons.task_alt_rounded;
    } else if (isPending) {
      statusColor = AppColors.warning;
      statusIcon = Icons.schedule_rounded;
    } else {
      statusColor = AppColors.error;
      statusIcon = Icons.block_rounded;
    }
    
    Color typeColor;
    if (type.toLowerCase() == 'prospect') {
      typeColor = Colors.orange;
    } else if (type.toLowerCase() == 'site') {
      typeColor = AppColors.success;
    } else {
      typeColor = const Color(0xFF197ADC); // Bright blue
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Avatar & Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar & Party Badge
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 26.r,
                          backgroundColor: typeColor,
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 16.w),
                    
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name and Top Right Icon
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      ownerName,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Top Right Badge Icon (Status)
                              Container(
                                padding: EdgeInsets.all(6.r),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  statusIcon,
                                  color: statusColor,
                                  size: 16.sp,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          
                          // Address
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14.sp,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  address,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                

                
                SizedBox(height: 16.h),
                
                // Bottom Buttons
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12.r),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12.r),
                          onTap: onOpenMap,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primary, width: 1.2),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.map_outlined, size: 16.sp, color: AppColors.primary),
                                SizedBox(width: 8.w),
                                Text(
                                  'View Map',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12.r),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12.r),
                          onTap: onOpenDirections,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.success, width: 1.2),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_outlined, size: 16.sp, color: AppColors.success),
                                SizedBox(width: 8.w),
                                Text(
                                  'Directions',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                if (isPending) ...[
                  SizedBox(height: 16.h),
                  if (!isStarted) _buildGeofenceBanner(),
                  if (isStarted)
                    CustomButton(
                      label: 'Stop',
                      onPressed: onStop,
                      backgroundColor: AppColors.error,
                    )
                  else
                    CustomButton(
                      label: 'Start',
                      onPressed: canCheckIn ? onStart : null,
                      isDisabled: !canCheckIn,
                      type: ButtonType.primary,
                    ),
                  SizedBox(height: 12.h),
                  if (!isStarted)
                    Material(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12.r),
                      onTap: onSkip,
                      child: Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.error, width: 1.2),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else if (status.toLowerCase() == 'skipped' && startTime != null) ...[
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Container(
                      height: 38.h, // Matches the approximate height of the 2-line columns
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.block_rounded, size: 16.sp, color: AppColors.error),
                          SizedBox(width: 8.w),
                          Text(
                            'Skipped at $startTime',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (startTime != null && endTime != null) ...[
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        _buildStatColumn('Started', startTime!, Icons.play_circle_outline_rounded, AppColors.textSecondary),
                        Container(width: 1.w, height: 32.h, color: AppColors.border),
                        _buildStatColumn('Ended', endTime!, Icons.stop_circle_outlined, AppColors.textSecondary),
                        if (timeSpent != null) ...[
                          Container(width: 1.w, height: 32.h, color: AppColors.border),
                          _buildStatColumn('Time Spent', timeSpent!, Icons.timer_outlined, AppColors.primary, valueColor: AppColors.primary),
                        ]
                      ],
                    ),
                  ),
                ],
                if (isVisited && _hasVisitExtras) ...[
                  if (photoUrl != null) ...[
                    SizedBox(height: 12.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.network(
                        photoUrl!,
                        height: 160.h,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : Container(
                                    height: 160.h,
                                    alignment: Alignment.center,
                                    color: AppColors.surface,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                        errorBuilder: (context, _, __) => Container(
                          height: 160.h,
                          alignment: Alignment.center,
                          color: AppColors.surface,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textSecondary,
                            size: 28.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (notes != null && notes!.trim().isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.sticky_note_2_outlined,
                            size: 16.sp, color: AppColors.textSecondary),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            notes!.trim(),
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (followUp != null) ...[
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Icon(Icons.event_repeat_rounded,
                            size: 16.sp, color: AppColors.primary),
                        SizedBox(width: 8.w),
                        Text(
                          'Follow-up: $followUp',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasVisitExtras =>
      photoUrl != null ||
      (notes != null && notes!.trim().isNotEmpty) ||
      followUp != null;

  /// Geofence status shown above the Start button for a pending stop:
  /// green "within range" when the rep is close enough to check in, amber
  /// "move closer" with the distance when out of range, or a neutral
  /// "waiting for your location" when we don't have a position yet. Renders
  /// nothing in non-geofenced contexts (no measurement + check-in allowed).
  Widget _buildGeofenceBanner() {
    final hasProximity = proximityMeters != null;
    if (canCheckIn && !hasProximity) return const SizedBox.shrink();

    final Color color;
    final IconData icon;
    final String text;
    if (canCheckIn) {
      color = AppColors.success;
      icon = Icons.where_to_vote_rounded;
      text = 'Within range — you can check in'
          '${hasProximity ? ' (${formatDistanceMeters(proximityMeters!)})' : ''}';
    } else if (hasProximity) {
      color = AppColors.warning;
      icon = Icons.location_searching_rounded;
      text = 'Move closer to check in — '
          '${formatDistanceMeters(proximityMeters!)} away';
    } else {
      color = AppColors.textSecondary;
      icon = Icons.gps_not_fixed_rounded;
      text = 'Waiting for your location…';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16.sp, color: color),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color iconColor, {Color? valueColor}) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14.sp, color: iconColor),
              SizedBox(width: 4.w),
              Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500)),
            ],
          ),
          SizedBox(height: 4.h),
          Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

