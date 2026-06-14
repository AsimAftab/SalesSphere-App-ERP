import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../controllers/beat_plan_controller.dart';
import '../../domain/entities/beat_plan.dart';

class BeatPlanCard extends ConsumerWidget {
  final BeatPlan plan;

  const BeatPlanCard({super.key, required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Future: Navigate to detail page
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatusBadge(
                      label: plan.status,
                      color: _getStatusColor(plan.status),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date Row 1
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Text(
                      'Assigned: ${DateFormat('MMM dd, yyyy').format(plan.assignedDate)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (plan.status.toLowerCase() != 'pending') ...[
                  const SizedBox(height: 4),
                  // Date Row 2
                  Row(
                    children: [
                      Icon(Icons.access_time_outlined, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Text(
                        'Started: ${DateFormat('MMM dd, yyyy').format(plan.startedDate)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(plan.progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Animated Progress Bar
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.easeOutQuart,
                                height: 8,
                                // If progress is 0, give it a tiny width so the rounded corner is visible
                                width: plan.progress == 0 ? 8 : constraints.maxWidth * plan.progress,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    if (plan.progress > 0)
                                      BoxShadow(
                                        color: AppColors.success.withValues(alpha: 0.3),
                                        blurRadius: 6,
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
                const SizedBox(height: 16),

                // Subtle Divider
                Divider(color: Colors.grey.shade200, height: 1, thickness: 1),
                const SizedBox(height: 12),

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

                const SizedBox(height: 16),
                if (plan.status.toLowerCase() == 'pending')
                  PrimaryButton(
                    label: 'Start Beat',
                    onPressed: () {
                      ref.read(beatPlanControllerProvider.notifier).startPlan(plan.id);
                      context.push(Routes.beatPlanDetailPath(plan.id));
                    },
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

  Widget _buildStatItem(String count, String label, Color countColor) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            color: countColor,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
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
