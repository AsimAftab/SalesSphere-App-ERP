import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan_stop.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/providers/beat_plan_providers.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/widgets/end_visit_sheet.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/widgets/route_progress_card.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/widgets/route_stop_card.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/widgets/tracking_status_card.dart';
import 'package:sales_sphere_erp/features/tracking/domain/tracking_live_state.dart';
import 'package:sales_sphere_erp/features/tracking/domain/usecases/start_tracking_usecase.dart';
import 'package:sales_sphere_erp/features/tracking/presentation/controllers/tracking_controller.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_service.dart';
import 'package:sales_sphere_erp/shared/utils/maps_launcher.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

const List<String> _tabs = <String>['All', 'Pending', 'Visited', 'Skipped'];

class BeatPlanDetailPage extends ConsumerStatefulWidget {
  const BeatPlanDetailPage({required this.id, super.key});

  final String id;

  @override
  ConsumerState<BeatPlanDetailPage> createState() => _BeatPlanDetailPageState();
}

class _BeatPlanDetailPageState extends ConsumerState<BeatPlanDetailPage> {
  String _selectedTab = 'All';

  /// When the rep tapped "Start" on a stop → becomes the visit's
  /// `visitStartedAt`. In-memory for the session (a process restart clears it,
  /// so they'd re-start the stop).
  final Map<String, DateTime> _startedAt = <String, DateTime>{};

  @override
  Widget build(BuildContext context) {
    // Surface "session ended" notices (force-stop reason / stop) as a snackbar.
    ref.listen<String?>(trackingNoticeProvider, (previous, next) {
      if (next != null && mounted) {
        SnackbarUtils.showInfo(context, next);
        ref.read(trackingNoticeProvider.notifier).clear();
      }
    });

    final planAsync = ref.watch(beatPlanByIdProvider(widget.id));
    final stopsAsync = ref.watch(beatPlanStopsProvider(widget.id));
    final live = ref.watch(trackingControllerProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _header(context, live.isFor(widget.id)),
              SizedBox(height: 12.h),
              Expanded(
                child: planAsync.when(
                  data: (plan) {
                    if (plan == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final stops = stopsAsync.value ?? const <BeatPlanStop>[];
                    return _body(context, plan, stops, live);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Could not load this beat plan.')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool tracking) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 20.w, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20.sp),
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
          if (tracking)
            StatusBadge(
              label: 'Tracking',
              color: AppColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    BeatPlan plan,
    List<BeatPlanStop> stops,
    TrackingLiveState live,
  ) {
    final isLive = live.isFor(plan.id);
    final filtered = _filteredStops(stops);
    final activeStopId = _activeStopId(stops);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(beatPlanControllerProvider.notifier).refresh();
        ref.invalidate(beatPlanByIdProvider(widget.id));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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
                  color: _statusColor(plan.status),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ],
            ),
            const SizedBox(height: 24),
            RouteProgressCard(plan: plan),
            SizedBox(height: 20.h),
            _trackingSection(context, plan, live, isLive),
            SizedBox(height: 28.h),
            Text(
              'Route Stops',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 16.h),
            _tabBar(stops),
            SizedBox(height: 20.h),
            if (filtered.isEmpty)
              _emptyStops()
            else
              ...filtered.map(
                (stop) => _stopCard(context, plan, stop, stop.id == activeStopId),
              ),
          ],
        ),
      ),
    );
  }

  Widget _trackingSection(
    BuildContext context,
    BeatPlan plan,
    TrackingLiveState live,
    bool isLive,
  ) {
    if (isLive) {
      // Display-only: tracking is system-controlled — the rep can't pause or
      // stop it. It ends when the plan is completed/force-completed, on
      // attendance checkout, or via the stale-session sweeper.
      return TrackingStatusCard(
        duration: live.durationLabel,
        distanceKm: live.distanceKm,
        queuedCount: live.queued,
        isConnected: live.connected,
        isPaused: live.isPaused,
      );
    }
    if (plan.isCompleted) return const SizedBox.shrink();
    return PrimaryButton(
      label: plan.isActive ? 'Resume Tracking' : 'Start Tracking',
      onPressed: () => _startTracking(plan),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  Future<void> _startTracking(BeatPlan plan) async {
    final notifier = ref.read(trackingControllerProvider.notifier);
    final result =
        plan.isActive ? await notifier.resumeForPlan(plan) : await notifier.startForPlan(plan);
    if (!mounted) return;
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
    }
  }

  Future<void> _endVisit(
    BeatPlan plan,
    BeatPlanStop stop, {
    required String notes,
    required String photoPath,
    DateTime? followUpDate,
  }) async {
    final startedAt = _startedAt[stop.id];
    setState(() => _startedAt.remove(stop.id));
    try {
      await ref.read(beatPlanControllerProvider.notifier).visitStop(
            beatPlanId: plan.id,
            stopId: stop.id,
            visitStartedAt: startedAt,
            notes: notes,
            followUpDate: followUpDate,
            imagePath: photoPath,
          );
      _syncProgressToService(plan, visited: true);
      if (mounted) SnackbarUtils.showSuccess(context, 'Visit recorded.');
    } on Object {
      if (mounted) SnackbarUtils.showError(context, 'Could not record the visit.');
    }
  }

  Future<void> _skipStop(BeatPlan plan, BeatPlanStop stop) async {
    try {
      await ref.read(beatPlanControllerProvider.notifier).skipStop(
            beatPlanId: plan.id,
            stopId: stop.id,
          );
      _syncProgressToService(plan, visited: false);
      if (mounted) SnackbarUtils.showInfo(context, 'Stop skipped.');
    } on Object {
      if (mounted) SnackbarUtils.showError(context, 'Could not skip the stop.');
    }
  }

  /// Push the new visited/skipped counts to the running service so the
  /// notification progress stays in sync.
  void _syncProgressToService(BeatPlan plan, {required bool visited}) {
    final live = ref.read(trackingControllerProvider);
    if (!live.isFor(plan.id)) return;
    updateTrackingProgress(
      total: plan.total,
      visited: live.visited + (visited ? 1 : 0),
      skipped: live.skipped + (visited ? 0 : 1),
    );
  }

  // ── Stop card ───────────────────────────────────────────────────────────
  Widget _stopCard(
    BuildContext context,
    BeatPlan plan,
    BeatPlanStop stop,
    bool isActive,
  ) {
    final startedLabel = stop.visitStartedAt == null
        ? null
        : DateFormat('hh:mm a').format(stop.visitStartedAt!.toLocal());
    final endedLabel = stop.visitedAt == null
        ? null
        : DateFormat('hh:mm a').format(stop.visitedAt!.toLocal());
    final followUpLabel = stop.followUpDate == null
        ? null
        : DateFormat('dd MMM yyyy').format(stop.followUpDate!.toLocal());
    return RouteStopCard(
      name: stop.name ?? 'Unnamed stop',
      ownerName: stop.typeLabel,
      type: stop.typeLabel,
      address: stop.address ?? 'No address',
      status: stop.statusLabel,
      distance: stop.distanceToNextKm == null
          ? ''
          : '${stop.distanceToNextKm!.toStringAsFixed(1)} km',
      isActive: isActive,
      isStarted: _startedAt.containsKey(stop.id),
      startTime: stop.isSkipped ? endedLabel : (stop.isVisited ? startedLabel : null),
      endTime: stop.isVisited ? endedLabel : null,
      timeSpent: stop.isVisited ? stop.timeSpentLabel : null,
      notes: stop.isVisited ? stop.visitNotes : null,
      photoUrl: stop.isVisited ? stop.visitImageUrl : null,
      followUp: stop.isVisited ? followUpLabel : null,
      onTap: () {},
      onOpenMap: () => _openMaps(stop, directions: false),
      onOpenDirections: () => _openMaps(stop, directions: true),
      onStart: () => setState(() => _startedAt[stop.id] = DateTime.now()),
      onStop: () => _showEndVisitSheet(plan, stop),
      onSkip: () => _confirmSkip(plan, stop),
    );
  }

  Future<void> _openMaps(BeatPlanStop stop, {required bool directions}) async {
    if (!stop.hasLocation) {
      SnackbarUtils.showWarning(context, 'No location saved for this stop.');
      return;
    }
    final launched = directions
        ? await openDirections(lat: stop.latitude!, lng: stop.longitude!)
        : await openInMaps(lat: stop.latitude!, lng: stop.longitude!);
    if (!launched && mounted) {
      SnackbarUtils.showError(context, "Couldn't open Google Maps.");
    }
  }

  void _showEndVisitSheet(BeatPlan plan, BeatPlanStop stop) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EndVisitSheet(
        entity: <String, dynamic>{'name': stop.name ?? 'Stop'},
        onEndVisit: ({required notes, required photoPath, followUpDate}) =>
            _endVisit(
          plan,
          stop,
          notes: notes,
          photoPath: photoPath,
          followUpDate: followUpDate,
        ),
      ),
    );
  }

  Future<void> _confirmSkip(BeatPlan plan, BeatPlanStop stop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: const Text('Skip stop?'),
        content: Text(
          'Skip ${stop.name ?? 'this stop'}? This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Skip', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _skipStop(plan, stop);
    }
  }

  // ── Layout helpers ──────────────────────────────────────────────────────
  Widget _tabBar(List<BeatPlanStop> stops) {
    return Row(
      children: _tabs.asMap().entries.map((entry) {
        final index = entry.key;
        final tab = entry.value;
        final isSelected = _selectedTab == tab;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == _tabs.length - 1 ? 0 : 8.w),
            child: InkWell(
              onTap: () => setState(() => _selectedTab = tab),
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
                  tab == 'All' ? 'All (${stops.length})' : tab,
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
    );
  }

  Widget _emptyStops() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 48.h),
      child: Center(
        child: Column(
          children: <Widget>[
            Icon(Icons.route_rounded, size: 48.sp,
                color: AppColors.primary.withValues(alpha: 0.5)),
            SizedBox(height: 16.h),
            Text(
              _selectedTab == 'All' ? 'No route stops' : 'Nothing here',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BeatPlanStop> _filteredStops(List<BeatPlanStop> stops) {
    final list = _selectedTab == 'All'
        ? List<BeatPlanStop>.from(stops)
        : stops.where((s) => s.statusLabel == _selectedTab).toList();
    list.sort((a, b) {
      int weight(BeatPlanStop s) => s.isPending ? 0 : (s.isVisited ? 1 : 2);
      final w = weight(a).compareTo(weight(b));
      if (w != 0) return w;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return list;
  }

  String? _activeStopId(List<BeatPlanStop> stops) {
    for (final s in stops) {
      if (s.isPending) return s.id;
    }
    return null;
  }

  Color _statusColor(String status) {
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
