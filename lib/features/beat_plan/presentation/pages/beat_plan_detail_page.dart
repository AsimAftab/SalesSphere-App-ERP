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
import '../../../../shared/widgets/custom_button.dart';
import '../providers/beat_plan_providers.dart';
import '../widgets/route_stop_card.dart';
import '../widgets/tracking_status_card.dart';
import '../widgets/route_progress_card.dart';
import '../widgets/end_visit_sheet.dart';
import '../../domain/beat_plan.dart';

class BeatPlanDetailPage extends ConsumerStatefulWidget {
  final String id;
  const BeatPlanDetailPage({super.key, required this.id});

  @override
  ConsumerState<BeatPlanDetailPage> createState() => _BeatPlanDetailPageState();
}

class _BeatPlanDetailPageState extends ConsumerState<BeatPlanDetailPage> {
  String _selectedTab = 'All';

  late List<Map<String, dynamic>> _entities;

  @override
  void initState() {
    super.initState();
    _entities = [
      {'name': 'TechMart Solutions', 'ownerName': 'John Doe', 'type': 'Party', 'address': '104, Cyber Park, Electronic City', 'status': 'Visited', 'distance': '0.2 km', 'isActive': false, 'lat': 12.8452, 'lng': 77.6602, 'startTime': '10:30 AM', 'endTime': '11:15 AM', 'timeSpent': '45 mins'},
      {'name': 'Innovatech Systems', 'ownerName': 'Jane Smith', 'type': 'Site', 'address': 'Building 4, Cyber Space', 'status': 'Visited', 'distance': '0.8 km', 'isActive': false, 'lat': 12.8462, 'lng': 77.6612, 'startTime': '12:15 PM', 'endTime': '01:25 PM', 'timeSpent': '1 hr 10 mins'},
      {'name': 'Alpha Distribution', 'ownerName': 'Michael Lee', 'type': 'Prospect', 'address': 'Warehouse Zone, East End', 'status': 'Visited', 'distance': '1.2 km', 'isActive': false, 'lat': 12.8472, 'lng': 77.6622, 'startTime': '02:45 PM', 'endTime': '03:15 PM', 'timeSpent': '30 mins'},
      {'name': 'Global Retailers Ltd', 'ownerName': 'Sarah Connor', 'type': 'Party', 'address': 'Block A, Grand Mall, Central Ave', 'status': 'Pending', 'distance': '1.5 km', 'isActive': true, 'lat': 12.8482, 'lng': 77.6632},
      {'name': 'Smart Solutions Inc', 'ownerName': 'David Kim', 'type': 'Site', 'address': 'Floor 3, Tech Hub, Ring Road', 'status': 'Skipped', 'distance': '4.2 km', 'isActive': false, 'lat': 12.8492, 'lng': 77.6642, 'startTime': '04:00 PM', 'endTime': '04:00 PM', 'timeSpent': '0 mins'},
    ];
  }

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
                        final filteredEntities = _selectedTab == 'All' 
                            ? List<Map<String, dynamic>>.from(_entities)
                            : _entities.where((e) => e['status'] == _selectedTab).toList();

                        filteredEntities.sort((a, b) {
                          final aWeight = a['status'] == 'Pending' ? 0 : (a['status'] == 'Visited' ? 1 : 2);
                          final bWeight = b['status'] == 'Pending' ? 0 : (b['status'] == 'Visited' ? 1 : 2);
                          if (aWeight != bWeight) return aWeight.compareTo(bWeight);
                          return (a['name'] as String).compareTo(b['name'] as String);
                        });

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

                // Route Progress Card
                RouteProgressCard(plan: plan),
                SizedBox(height: 24.h),

                // Live Tracking Status Card
                const TrackingStatusCard(
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
                              tab == 'All' ? 'All (${_entities.length})' : tab,
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
                    padding: EdgeInsets.symmetric(vertical: 48.h),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedTab == 'Pending' ? Icons.schedule_rounded
                                : _selectedTab == 'Visited' ? Icons.task_alt_rounded
                                : _selectedTab == 'Skipped' ? Icons.block_rounded
                                : Icons.route_rounded,
                              size: 48.sp,
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            _selectedTab == 'Pending' ? 'All Caught Up!'
                                : _selectedTab == 'Visited' ? 'No Stops Visited Yet'
                                : _selectedTab == 'Skipped' ? 'No Skipped Stops'
                                : 'No Route Stops',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _selectedTab == 'Pending' ? 'You have no pending stops right now.'
                                : _selectedTab == 'Visited' ? 'Start your route and log your visits here.'
                                : _selectedTab == 'Skipped' ? 'You haven\'t skipped any stops.'
                                : 'There are no stops assigned to this route.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filteredEntities.map((e) => RouteStopCard(
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
                      setState(() {
                        e['isStarted'] = true;
                      });
                    },
                    onStop: () {
                      _showEndVisitBottomSheet(e);
                    },
                    isStarted: e['isStarted'] == true,
                    onSkip: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                          contentPadding: EdgeInsets.all(24.w),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Skip Stop?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18.sp,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary, height: 1.4),
                                  children: [
                                    const TextSpan(text: 'Are you sure you want to skip '),
                                    TextSpan(
                                      text: '${e['name']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                    const TextSpan(text: '? This action cannot be undone.'),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedCustomButton(
                                      label: 'Cancel',
                                      onPressed: () => Navigator.of(ctx).pop(),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: CustomButton(
                                      label: 'Yes, Skip',
                                      backgroundColor: AppColors.error,
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        // TODO: Implement actual skip logic via controller
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
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

  void _showEndVisitBottomSheet(Map<String, dynamic> e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EndVisitSheet(
        entity: e,
        onEndVisit: () {
          setState(() {
            e['status'] = 'Visited';
            e['startTime'] = '09:00 AM'; // Dummy data for demonstration
            e['endTime'] = '09:45 AM';
            e['timeSpent'] = '45 mins';
            e.remove('isStarted');
          });
        },
      ),
    );
  }
}
