import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan.dart';
import 'package:sales_sphere_erp/features/tracking/domain/usecases/start_tracking_usecase.dart';
import 'package:sales_sphere_erp/features/tracking/presentation/controllers/tracking_controller.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';

class BeatPlanSummaryCard extends ConsumerWidget {
  final BeatPlan plan;

  const BeatPlanSummaryCard({required this.plan, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24.r,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: () {
            context.push(Routes.beatPlanDetailPath(plan.id));
          },
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        plan.title,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    StatusBadge(
                      label: plan.status,
                      color: _getStatusColor(plan.status),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Date Info
                Row(
                  children: [
                    // Assigned Date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14.sp, color: Colors.grey.shade400),
                            SizedBox(width: 6.w),
                            Text(
                              'Assigned',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          DateFormat('dd MMM yyyy').format(plan.assignedDate),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    if (plan.status.toLowerCase() != 'pending') ...[
                      SizedBox(width: 48.w),
                      // Started Date
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time_outlined, size: 14.sp, color: Colors.grey.shade400),
                              SizedBox(width: 6.w),
                              Text(
                                'Started',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            DateFormat('dd MMM yyyy').format(plan.startedDate),
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 16.h),

                // Progress Section
                Opacity(
                  opacity: plan.status.toLowerCase() == 'pending' ? 0.4 : 1.0,
                  child: Column(
                    children: [
                      // Progress Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(plan.progress * 100).toInt()}%',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),

                      // Animated Progress Bar
                      Stack(
                        children: [
                          Container(
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.easeOutQuart,
                                height: 8.h,
                                width: plan.progress == 0 ? 8.w : constraints.maxWidth * plan.progress,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(10.r),
                                  boxShadow: [
                                    if (plan.progress > 0)
                                      BoxShadow(
                                        color: AppColors.success.withValues(alpha: 0.3),
                                        blurRadius: 6.r,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                // Subtle Divider
                Divider(color: Colors.grey.shade200, height: 1, thickness: 1),
                SizedBox(height: 12.h),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(plan.total.toString(), 'Total', AppColors.textPrimary),
                    _buildStatItem(plan.visited.toString(), 'Visited', AppColors.success),
                    _buildStatItem(plan.pending.toString(), 'Pending', AppColors.warning),
                    _buildStatItem(plan.skipped.toString(), 'Skipped', AppColors.error),
                  ],
                ),

                SizedBox(height: 16.h),
                if (plan.status.toLowerCase() == 'pending')
                  PrimaryButton(
                    label: 'Start Beat',
                    onPressed: () => _startBeat(context, ref, plan),
                  )
                else
                  PrimaryButton(
                    label: 'View Details',
                    onPressed: () {
                      context.push(Routes.beatPlanDetailPath(plan.id));
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startBeat(
    BuildContext context,
    WidgetRef ref,
    BeatPlan plan,
  ) async {
    final result =
        await ref.read(trackingControllerProvider.notifier).startForPlan(plan);
    if (!context.mounted) return;
    switch (result.outcome) {
      case StartTrackingOutcome.permissionDenied:
        SnackbarUtils.showWarning(
          context,
          result.message ?? 'Location permission is required.',
        );
      case StartTrackingOutcome.error:
        SnackbarUtils.showError(
          context,
          result.message ?? 'Could not start tracking.',
        );
      case StartTrackingOutcome.started:
        if (result.warning != null) {
          SnackbarUtils.showWarning(context, result.warning!);
        }
        context.push(Routes.beatPlanDetailPath(plan.id));
    }
  }

  Widget _buildStatItem(String count, String label, Color countColor) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            color: countColor,
            fontWeight: FontWeight.w800,
            fontSize: 20.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF197ADC); // AppColors.secondary
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
}
