import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';

class BeatEntityCard extends StatelessWidget {
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
  final VoidCallback onSkip;

  const BeatEntityCard({
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
    required this.onSkip,
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
                                        fontSize: 13.sp,
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
                                    fontSize: 13.sp,
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
                                    fontSize: 13.sp,
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
                  CustomButton(
                    label: 'Start',
                    onPressed: onStart,
                    type: ButtonType.primary,
                  ),
                  SizedBox(height: 12.h),
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
                ] else if (startTime != null && endTime != null) ...[
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.play_circle_outline_rounded, size: 18.sp, color: AppColors.textSecondary),
                                SizedBox(width: 8.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Started', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500)),
                                    SizedBox(height: 2.h),
                                    Text(startTime!, style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ],
                            ),
                            Container(width: 1.w, height: 28.h, color: AppColors.border),
                            Row(
                              children: [
                                Icon(Icons.stop_circle_outlined, size: 18.sp, color: AppColors.textSecondary),
                                SizedBox(width: 8.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Ended', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500)),
                                    SizedBox(height: 2.h),
                                    Text(endTime!, style: TextStyle(color: AppColors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (timeSpent != null) ...[
                          SizedBox(height: 12.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer_outlined, size: 16.sp, color: AppColors.primary),
                                SizedBox(width: 6.w),
                                Text(
                                  'Time Spent: $timeSpent',
                                  style: TextStyle(color: AppColors.primary, fontSize: 12.sp, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

