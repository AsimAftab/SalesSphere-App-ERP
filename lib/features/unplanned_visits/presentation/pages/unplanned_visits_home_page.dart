import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/auth/permissions.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_today_status.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit_exceptions.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visits_monthly_report.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visits_today.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/controllers/unplanned_visit_controller.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/providers/unplanned_visit_providers.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/widgets/stop_visit_sheet.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/widgets/visit_out_of_range_dialog.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/widgets/visit_summary_card.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/widgets/visit_target_picker.dart';
import 'package:sales_sphere_erp/shared/utils/error_messages.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/check_in_required_dialog.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:sales_sphere_erp/shared/widgets/summary_stats_card.dart';
import 'package:sales_sphere_erp/shared/widgets/today_status_card.dart';
import 'package:skeletonizer/skeletonizer.dart';

class UnplannedVisitsHomePage extends ConsumerWidget {
  const UnplannedVisitsHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayAsync = ref.watch(unplannedVisitsTodayProvider);
    final summary =
        ref
            .watch(unplannedVisitsMonthlyReportProvider(now.year, now.month))
            .value
            ?.summary ??
        UnplannedVisitsMonthlySummary.empty;
    final canRecord = ref.watch(
      hasPermissionProvider(Permissions.unplannedVisitRecord),
    );

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SvgPicture.asset(
                'assets/images/corner_bubble.svg',
                fit: BoxFit.cover,
                height: 180.h,
              ),
            ),
            SafeArea(
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
                          constraints: BoxConstraints(
                            minWidth: 36.w,
                            minHeight: 36.h,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'Unplanned Visits',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref
                          ..invalidate(unplannedVisitsTodayProvider)
                          ..invalidate(
                            unplannedVisitsMonthlyReportProvider(
                              now.year,
                              now.month,
                            ),
                          );
                        await ref.read(unplannedVisitsTodayProvider.future);
                      },
                      child: todayAsync.when(
                        loading: () => const _HomeSkeleton(),
                        error: (_, __) => _ScrollableCenter(
                          child: _ErrorRetry(
                            onRetry: () =>
                                ref.invalidate(unplannedVisitsTodayProvider),
                          ),
                        ),
                        data: (status) => _Content(
                          status: status,
                          summary: summary,
                          canRecord: canRecord,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.status,
    required this.summary,
    required this.canRecord,
  });

  final UnplannedVisitsToday status;
  final UnplannedVisitsMonthlySummary summary;
  final bool canRecord;

  @override
  Widget build(BuildContext context) {
    final activeVisit = status.activeVisit;
    final completed = status.completedVisits;
    // Number by chronological order so "Visit 1" is the day's first visit
    // (matches the detail page), but display the active visit first.
    final chrono = <UnplannedVisit>[...status.visits]..sort((a, b) {
      final at = a.startedAt ?? a.createdAt;
      final bt = b.startedAt ?? b.createdAt;
      if (at == null || bt == null) return 0;
      return at.compareTo(bt);
    });
    final numbers = <String, int>{
      for (var i = 0; i < chrono.length; i++) chrono[i].id: i + 1,
    };
    final ordered = <UnplannedVisit>[
      if (activeVisit != null) activeVisit,
      for (final v in chrono)
        if (v.id != activeVisit?.id) v,
    ];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TodayStatusCard(
            icon: Icons.pin_drop_rounded,
            title: "Today's Status",
            statusBadge: activeVisit != null
                ? const StatusBadge(label: 'On Visit', color: AppColors.blue500)
                : completed.isNotEmpty
                ? const StatusBadge(
                    label: 'Completed',
                    color: AppColors.green500,
                  )
                : const StatusBadge(
                    label: 'Not Started',
                    color: AppColors.textSecondary,
                  ),
          ),
          if (activeVisit != null) ...<Widget>[
            if (canRecord) ...<Widget>[
              SizedBox(height: 16.h),
              // Status lives in the Today's Status card and the carousel below —
              // this is just the action.
              CustomButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => StopVisitSheet(visit: activeVisit),
                ),
                label: 'Complete Visit ->',
                backgroundColor: AppColors.red500,
              ),
            ],
          ] else if (canRecord) ...<Widget>[
            SizedBox(height: 24.h),
            const _StartVisitButton(),
          ],
          SizedBox(height: 32.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.timeline_rounded,
                    color: AppColors.blue500,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    "Today's Visits",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                '${completed.length} / ${ordered.length}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (ordered.isEmpty)
            const _EmptyToday()
          else
            _VisitsCarousel(visits: ordered, numbers: numbers),
          SizedBox(height: 24.h),
          SummaryStatsCard(
            title: 'Monthly Summary',
            icon: Icons.insights_rounded,
            crossAxisCount: 3,
            onViewDetails: () =>
                context.pushNamed(Routes.unplannedVisitsHistoryName),
            stats: <SummaryStatTile>[
              SummaryStatTile(
                value: '${summary.totalVisits}',
                label: 'Total Visits',
              ),
              SummaryStatTile(
                value: '${summary.visitsCompleted}',
                label: 'Completed',
              ),
              SummaryStatTile(
                value: '${summary.visitsInProgress}',
                label: 'In Progress',
              ),
            ],
          ),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }
}

/// Swipeable carousel of the day's visits with animated page dots — mirrors
/// the odometer home carousel.
class _VisitsCarousel extends StatefulWidget {
  const _VisitsCarousel({required this.visits, required this.numbers});

  final List<UnplannedVisit> visits;

  /// Visit id → chronological "Visit N" number (the display order is
  /// active-first, so it doesn't match the card positions).
  final Map<String, int> numbers;

  @override
  State<_VisitsCarousel> createState() => _VisitsCarouselState();
}

class _VisitsCarouselState extends State<_VisitsCarousel> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visits = widget.visits;
    return Column(
      children: <Widget>[
        SizedBox(
          height: 184.h,
          child: PageView.builder(
            controller: _controller,
            clipBehavior: Clip.none,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final visit = visits[index];
              return VisitSummaryCard(
                visit: visit,
                number: widget.numbers[visit.id] ?? (index + 1),
                // A carousel card is one specific visit → open it directly
                // (focused single view), not the day-grouped tabs/list.
                onTap: () => context.pushNamed(
                  Routes.unplannedVisitDetailName,
                  pathParameters: <String, String>{'id': visit.id},
                  queryParameters: <String, String>{'focus': '1'},
                ),
              );
            },
          ),
        ),
        if (visits.length > 1) ...<Widget>[
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(
              visits.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                width: _currentIndex == index ? 24.w : 8.w,
                height: 8.h,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? AppColors.blue500
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Start Visit" → pick target → geofence-gated start. Stateful so it can show
/// an inline spinner while resolving GPS + posting.
class _StartVisitButton extends ConsumerStatefulWidget {
  const _StartVisitButton();

  @override
  ConsumerState<_StartVisitButton> createState() => _StartVisitButtonState();
}

class _StartVisitButtonState extends ConsumerState<_StartVisitButton> {
  bool _isLoading = false;

  Future<void> _start() async {
    // Gate on attendance before the target picker — no point choosing a
    // customer / prospect / site if the server will reject the visit for not
    // being checked in.
    setState(() => _isLoading = true);
    bool checkedIn;
    try {
      final status = await ref.read(attendanceTodayStatusProvider.future);
      checkedIn = status.isCheckedIn;
    } on Exception {
      // Couldn't resolve attendance — don't hard-block; the server's
      // NOT_CHECKED_IN gate (caught below) is the backstop.
      checkedIn = true;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (!mounted) return;
    if (!checkedIn) {
      await _promptCheckIn('You must check in before starting a visit.');
      return;
    }

    final target = await showVisitTargetPicker(context);
    if (target == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(unplannedVisitControllerProvider.notifier)
          .startVisit(target);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Visit started.');
    } on VisitOutOfRangeException catch (e) {
      if (!mounted) return;
      await VisitOutOfRangeDialog.show(
        context,
        distanceMeters: e.distanceMeters,
        radiusMeters: e.radiusMeters,
        targetName: e.targetName,
        targetAddress: target.address,
      );
    } on UnplannedVisitConflictException catch (e) {
      if (!mounted) return;
      ref.invalidate(unplannedVisitsTodayProvider);
      SnackbarUtils.showInfo(context, e.message);
    } on VisitNotCheckedInException catch (e) {
      // Server backstop: attendance lapsed between the gate above and the POST.
      if (!mounted) return;
      await _promptCheckIn(e.message);
    } on Exception catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(context, userMessageFor(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows the check-in prompt and, if the rep opts in, routes to attendance.
  Future<void> _promptCheckIn(String message) async {
    final goToCheckIn =
        await CheckInRequiredDialog.show(context, message: message);
    if ((goToCheckIn ?? false) && mounted) {
      unawaited(context.push(Routes.attendance));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      onPressed: _start,
      isLoading: _isLoading,
      label: 'Start New Visit',
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday();

  @override
  Widget build(BuildContext context) {
    // Same empty-state copy, but housed in a white card so it sits in line
    // with the surrounding cards instead of floating on the background.
    return SectionCard(
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 24.w),
      children: const <Widget>[
        EmptyStateView(
          icon: Icons.pin_drop_outlined,
          title: 'No visits today',
          message: 'Logged visits appear here.',
        ),
      ],
    );
  }
}

/// Shimmer placeholders shown while today's status loads.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Bone(
              width: double.infinity,
              height: 64.h,
              borderRadius: BorderRadius.circular(16.r),
            ),
            SizedBox(height: 16.h),
            Bone(
              width: double.infinity,
              height: 56.h,
              borderRadius: BorderRadius.circular(16.r),
            ),
            SizedBox(height: 32.h),
            Bone(
              width: 140.w,
              height: 16.h,
              borderRadius: BorderRadius.circular(4.r),
            ),
            SizedBox(height: 16.h),
            Bone(
              width: double.infinity,
              height: 184.h,
              borderRadius: BorderRadius.circular(16.r),
            ),
            SizedBox(height: 24.h),
            Bone(
              width: double.infinity,
              height: 180.h,
              borderRadius: BorderRadius.circular(16.r),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scrollable wrapper so loading/error states still trigger pull-to-refresh.
class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(padding: EdgeInsets.all(32.w), child: child),
          ),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.cloud_off_rounded, color: AppColors.textHint, size: 48.sp),
        SizedBox(height: 16.h),
        Text(
          "Couldn't load your visits",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 16.h),
        OutlinedCustomButton(onPressed: onRetry, label: 'Retry'),
      ],
    );
  }
}
