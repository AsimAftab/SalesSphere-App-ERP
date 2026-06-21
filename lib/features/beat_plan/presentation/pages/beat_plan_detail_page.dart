import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/utils/geo_distance.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan_stop.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/providers/beat_plan_providers.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/visit_progress_store.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/widgets/end_visit_sheet.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/widgets/route_progress_card.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/widgets/route_stop_card.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/widgets/skip_stop_confirmation_dialog.dart';
import 'package:sales_sphere_erp/features/beat_plan/presentation/widgets/tracking_status_card.dart';
import 'package:sales_sphere_erp/features/tracking/domain/tracking_live_state.dart';
import 'package:sales_sphere_erp/features/tracking/domain/usecases/start_tracking_usecase.dart';
import 'package:sales_sphere_erp/features/tracking/presentation/controllers/tracking_controller.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_service.dart';
import 'package:sales_sphere_erp/shared/utils/maps_launcher.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
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
  /// `visitStartedAt`. Persisted via [VisitProgressStore] so an in-progress
  /// visit survives navigation, a tracking reconnect, or an app restart.
  final Map<String, DateTime> _startedAt = <String, DateTime>{};

  /// Guards the one-shot silent "ensure tracking is live" for an active plan
  /// (we don't show a manual resume button).
  bool _ensuredActiveTracking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStartedAt());
  }

  Future<void> _loadStartedAt() async {
    final saved = await VisitProgressStore.load();
    if (!mounted || saved.isEmpty) return;
    setState(() => _startedAt.addAll(saved));
  }

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
              _header(context, live),
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

  Widget _header(BuildContext context, TrackingLiveState live) {
    final tracking = live.isFor(widget.id);
    // Mirror the TrackingStatusCard's state so the header badge stays in sync:
    // green "Live" while streaming, amber "Paused"/"Offline" otherwise.
    final String trackingLabel;
    final Color trackingColor;
    if (live.isPaused) {
      trackingLabel = 'Paused';
      trackingColor = AppColors.warning;
    } else if (live.connected) {
      trackingLabel = 'Live';
      trackingColor = AppColors.success;
    } else {
      trackingLabel = 'Offline';
      trackingColor = AppColors.warning;
    }
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
              label: trackingLabel,
              color: trackingColor,
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
                      fontWeight: FontWeight.w700,
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
                fontWeight: FontWeight.w700,
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
                (stop) =>
                    _stopCard(context, plan, stop, stop.id == activeStopId, live),
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
        batteryLevel: live.batteryLevel,
      );
    }
    if (plan.isCompleted) return const SizedBox.shrink();
    if (plan.isActive) {
      // Tracking is automatic for an active plan — the rep never manually
      // "resumes". Silently make sure the service is live and show a brief
      // placeholder until its first state push flips this to the live card.
      if (!_ensuredActiveTracking) {
        _ensuredActiveTracking = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_ensureTrackingWithTimeout(plan));
        });
      }
      return _resumingPlaceholder();
    }
    // Pending → the single deliberate "start" action (runs the permission
    // gauntlet + REST start). There is no user-facing pause/resume/stop.
    return PrimaryButton(
      label: 'Start Tracking',
      onPressed: () => _startTracking(plan),
    );
  }

  /// Kicks off the background tracking service for an active plan, then guards
  /// against a silent failure (permissions revoked, OS restrictions): if the
  /// service hasn't pushed a live state for this plan within ~5s, reset the
  /// guard flag so a pull-to-refresh can retry instead of leaving the rep
  /// stuck on the resuming placeholder forever.
  Future<void> _ensureTrackingWithTimeout(BeatPlan plan) async {
    await ensureTrackingRunning(
      beatPlanId: plan.id,
      total: plan.total,
      visited: plan.visited,
      skipped: plan.skipped,
    );
    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    final live = ref.read(trackingControllerProvider);
    if (!live.isFor(plan.id)) {
      setState(() => _ensuredActiveTracking = false);
    }
  }

  Widget _resumingPlaceholder() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18.w,
            height: 18.w,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              'Resuming live tracking…',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  Future<void> _startTracking(BeatPlan plan) async {
    final notifier = ref.read(trackingControllerProvider.notifier);
    final result = await notifier.startForPlan(plan);
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
    unawaited(VisitProgressStore.remove(stop.id));
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
    TrackingLiveState live,
  ) {
    // Geofence (hard gate): a rep can only start a stop's visit while tracking
    // is live for this plan AND they're within `kGeofenceRadiusMeters` of it.
    // A stop with no saved location can't be geofenced, so it stays checkable.
    final geofenceActive = live.isFor(plan.id);
    final proximityMeters =
        geofenceActive ? stop.distanceMetersFrom(live.latitude, live.longitude) : null;
    final canCheckIn = !geofenceActive ||
        !stop.hasLocation ||
        (proximityMeters != null && proximityMeters <= kGeofenceRadiusMeters);

    final startedLabel = stop.visitStartedAt == null
        ? null
        : DateFormat('hh:mm a').format(stop.visitStartedAt!.toLocal());
    final endedLabel = stop.visitedAt == null
        ? null
        : DateFormat('hh:mm a').format(stop.visitedAt!.toLocal());
    final skippedLabel = stop.skippedAt == null
        ? null
        : DateFormat('hh:mm a').format(stop.skippedAt!.toLocal());
    final followUpLabel = stop.followUpDate == null
        ? null
        : DateFormat('dd MMM yyyy').format(stop.followUpDate!.toLocal());
    return RouteStopCard(
      key: ValueKey(stop.id),
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
      startTime: stop.isSkipped ? skippedLabel : (stop.isVisited ? startedLabel : null),
      endTime: stop.isVisited ? endedLabel : null,
      timeSpent: stop.isVisited ? stop.timeSpentLabel : null,
      notes: stop.isVisited ? stop.visitNotes : null,
      photoUrl: stop.isVisited ? stop.visitImageUrl : null,
      followUp: stop.isVisited ? followUpLabel : null,
      proximityMeters: proximityMeters,
      canCheckIn: canCheckIn,
      onTap: () {},
      onOpenMap: () => _openMaps(stop, directions: false),
      onOpenDirections: () => _openMaps(stop, directions: true),
      onStart: () => _startStopVisit(plan, stop),
      onStop: () => _showEndVisitSheet(plan, stop),
      onSkip: () => _confirmSkip(plan, stop),
    );
  }

  /// Begin a stop's visit. Re-verifies the geofence at tap time against the
  /// freshest live position (the badge/button can lag the live state by up to
  /// a tick) — a hard gate, so an out-of-range tap is refused with a hint
  /// rather than starting. Stops without coordinates aren't geofenced.
  void _startStopVisit(BeatPlan plan, BeatPlanStop stop) {
    final live = ref.read(trackingControllerProvider);
    if (live.isFor(plan.id) && stop.hasLocation) {
      final within = stop.isWithinRange(live.latitude, live.longitude);
      if (within != true) {
        final d = stop.distanceMetersFrom(live.latitude, live.longitude);
        SnackbarUtils.showWarning(
          context,
          d == null
              ? 'Waiting for your location — try again in a moment.'
              : "You're ${formatDistanceMeters(d)} away. Move within "
                  '${kGeofenceRadiusMeters.round()} m of the stop to start.',
        );
        return;
      }
    }
    final now = DateTime.now();
    setState(() => _startedAt[stop.id] = now);
    unawaited(VisitProgressStore.start(stop.id, now));
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
    final confirmed = await showSkipStopConfirmation(
      context,
      stopName: stop.name ?? 'this stop',
    );
    if (confirmed) {
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
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
      child: EmptyStateView(
        icon: Icons.route_rounded,
        title: _selectedTab == 'All' ? 'No route stops' : 'Nothing here',
        message: _selectedTab == 'All'
            ? 'Stops on this beat plan will appear here.'
            : 'No stops in this status.',
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
