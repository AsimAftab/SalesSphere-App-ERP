import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/utils/maps_launcher.dart';
import '../../../../shared/utils/snackbar_utils.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/status_bar_style.dart';
import '../controllers/beat_plan_controller.dart';
import '../widgets/beat_entity_card.dart';
import '../widgets/live_tracking_card.dart';
import '../../domain/entities/beat_plan.dart';

class BeatPlanDetailPage extends ConsumerStatefulWidget {
  final String id;
  const BeatPlanDetailPage({super.key, required this.id});

  @override
  ConsumerState<BeatPlanDetailPage> createState() => _BeatPlanDetailPageState();
}

class _BeatPlanDetailPageState extends ConsumerState<BeatPlanDetailPage> {
  String _selectedTab = 'All';

  @override
  Widget build(BuildContext context) {
    final beatPlansAsync = ref.watch(beatPlanControllerProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 4.h, 20.w, 0),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: AppColors.textPrimary,
                            size: 20.sp,
                          ),
                          onPressed: () => context.pop(),
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Beat Plan Details',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusBadge(
                          label: 'Tracking',
                          color: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Expanded(
                    child: beatPlansAsync.when(
                      data: (plans) {
                        final mockEntities = [
                          {'name': 'TechMart Solutions', 'ownerName': 'John Doe', 'type': 'Party', 'address': '104, Cyber Park, Electronic City', 'status': 'Visited', 'distance': '0.2 km', 'isActive': false, 'lat': 12.8452, 'lng': 77.6602, 'startTime': '10:30 AM', 'endTime': '11:15 AM', 'timeSpent': '45 mins'},
                          {'name': 'Innovatech Systems', 'ownerName': 'Jane Smith', 'type': 'Site', 'address': 'Building 4, Cyber Space', 'status': 'Visited', 'distance': '0.8 km', 'isActive': false, 'lat': 12.8462, 'lng': 77.6612, 'startTime': '12:15 PM', 'endTime': '01:25 PM', 'timeSpent': '1 hr 10 mins'},
                          {'name': 'Alpha Distribution', 'ownerName': 'Michael Lee', 'type': 'Prospect', 'address': 'Warehouse Zone, East End', 'status': 'Visited', 'distance': '1.2 km', 'isActive': false, 'lat': 12.8472, 'lng': 77.6622, 'startTime': '02:45 PM', 'endTime': '03:15 PM', 'timeSpent': '30 mins'},
                          {'name': 'Global Retailers Ltd', 'ownerName': 'Sarah Connor', 'type': 'Party', 'address': 'Block A, Grand Mall, Central Ave', 'status': 'Pending', 'distance': '1.5 km', 'isActive': true, 'lat': 12.8482, 'lng': 77.6632},
                          {'name': 'Smart Solutions Inc', 'ownerName': 'David Kim', 'type': 'Site', 'address': 'Floor 3, Tech Hub, Ring Road', 'status': 'Skipped', 'distance': '4.2 km', 'isActive': false, 'lat': 12.8492, 'lng': 77.6642, 'startTime': '04:00 PM', 'endTime': '04:00 PM', 'timeSpent': '0 mins'},
                        ];

                        final filteredEntities = _selectedTab == 'All' 
                            ? mockEntities 
                            : mockEntities.where((e) => e['status'] == _selectedTab).toList();

                        final plan = plans.firstWhere(
                          (p) => p.id == widget.id,
                          orElse: () => BeatPlan(
                            id: 'error',
                            title: 'Plan not found',
                            status: 'Unknown',
                            total: 0,
                            visited: 0,
                            pending: 0,
                            skipped: 0,
                            progress: 0,
                            assignedDate: DateTime.now(),
                            startedDate: DateTime.now(),
                          ),
                        );

                        if (plan.id == 'error') {
                          return const Center(child: Text('Plan not found'));
                        }

                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
                          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Name + Status)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        plan.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    StatusBadge(
                      label: plan.status,
                      color: _getStatusColor(plan.status),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Progress Card
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        blurRadius: 24.r,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Route Progress Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.route_outlined, color: AppColors.primary, size: 20.sp),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Route Progress',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              '${(plan.progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      
                      // Progress Bar
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            height: 8.h,
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Stack(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
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
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 24.h),
                      
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem('Total', plan.total.toString(), AppColors.textPrimary),
                          _buildStatItem('Visited', plan.visited.toString(), AppColors.success),
                          _buildStatItem('Pending', plan.pending.toString(), AppColors.warning),
                          _buildStatItem('Skipped', plan.skipped.toString(), AppColors.error),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // Information Note (Inside Card)
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20.sp),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                'Tracking will automatically stop when all entities are visited.',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Live Tracking Status Card
                const LiveTrackingCard(
                  duration: '2h 45m',
                  queuedCount: 0,
                  isConnected: true,
                ),
                SizedBox(height: 32.h),

                // Entities List Header
                Text(
                  'Route Stops',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16.h),

                // Tabs
                Row(
                  children: ['All', 'Pending', 'Visited', 'Skipped'].asMap().entries.map((entry) {
                    final index = entry.key;
                    final tab = entry.value;
                    final isSelected = _selectedTab == tab;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index == 3 ? 0 : 8.w),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTab = tab;
                            });
                          },
                          borderRadius: BorderRadius.circular(20.r),
                          child: Container(
                            alignment: Alignment.center,
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            child: Text(
                              tab == 'All' ? 'All (${mockEntities.length})' : tab,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20.h),

                // Filtered List
                if (filteredEntities.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.h),
                    child: Center(
                      child: Text(
                        'No stops found for this status.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  )
                else
                  ...filteredEntities.map((e) => BeatEntityCard(
                    name: e['name'] as String,
                    ownerName: e['ownerName'] as String,
                    type: e['type'] as String,
                    address: e['address'] as String,
                    status: e['status'] as String,
                    distance: e['distance'] as String,
                    isActive: e['isActive'] as bool,
                    startTime: e['startTime'] as String?,
                    endTime: e['endTime'] as String?,
                    timeSpent: e['timeSpent'] as String?,
                    onTap: () {},
                    onOpenMap: () async {
                      final launched = await openInMaps(lat: e['lat'] as double, lng: e['lng'] as double);
                      if (!launched && context.mounted) {
                        SnackbarUtils.showError(context, "Couldn't open Google Maps.");
                      }
                    },
                    onOpenDirections: () async {
                      final launched = await openDirections(lat: e['lat'] as double, lng: e['lng'] as double);
                      if (!launched && context.mounted) {
                        SnackbarUtils.showError(context, "Couldn't open Google Maps.");
                      }
                    },
                    onStart: () {
                      // Implement start functionality
                    },
                    onSkip: () {
                      // Implement skip functionality
                    },
                  )),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
                  ),
                ],
              ),
            ),
        ),
      );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.textSecondary,
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
        return const Color(0xFF4A90E2);
      case 'completed':
        return AppColors.success;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
