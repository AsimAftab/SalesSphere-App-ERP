import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/auth/permissions.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit_exceptions.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visits_today.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/controllers/unplanned_visit_controller.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/providers/unplanned_visit_providers.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/widgets/stop_visit_sheet.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/widgets/visit_card.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/widgets/visit_target_picker.dart';
import 'package:sales_sphere_erp/shared/utils/error_messages.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:sales_sphere_erp/shared/widgets/today_status_card.dart';

class UnplannedVisitsHomePage extends ConsumerWidget {
  const UnplannedVisitsHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(unplannedVisitsTodayProvider);
    final canRecord =
        ref.watch(hasPermissionProvider(Permissions.unplannedVisitRecord));

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
                          icon: Icon(Icons.arrow_back,
                              color: AppColors.textPrimary, size: 20.sp),
                          onPressed: () => context.pop(),
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints:
                              BoxConstraints(minWidth: 36.w, minHeight: 36.h),
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
                        ref.invalidate(unplannedVisitsTodayProvider);
                        await ref.read(unplannedVisitsTodayProvider.future);
                      },
                      child: todayAsync.when(
                        loading: () => const _ScrollableCenter(
                          child: CircularProgressIndicator(),
                        ),
                        error: (_, __) => _ScrollableCenter(
                          child: _ErrorRetry(
                            onRetry: () =>
                                ref.invalidate(unplannedVisitsTodayProvider),
                          ),
                        ),
                        data: (status) =>
                            _Content(status: status, canRecord: canRecord),
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
  const _Content({required this.status, required this.canRecord});

  final UnplannedVisitsToday status;
  final bool canRecord;

  @override
  Widget build(BuildContext context) {
    final activeVisit = status.activeVisit;
    final completed = status.completedVisits;
    final ordered = <UnplannedVisit>[
      if (activeVisit != null) activeVisit,
      ...completed,
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
                        label: 'Completed', color: AppColors.green500)
                    : const StatusBadge(
                        label: 'Not Started', color: AppColors.textSecondary),
          ),
          if (activeVisit != null) ...<Widget>[
            SizedBox(height: 16.h),
            _ActiveVisitCard(visit: activeVisit, canRecord: canRecord),
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
                  Icon(Icons.timeline_rounded,
                      color: AppColors.blue500, size: 20.sp),
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
            ...ordered.map(
              (v) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: VisitCard(
                  visit: v,
                  onTap: () => context.pushNamed(
                    Routes.unplannedVisitDetailName,
                    pathParameters: <String, String>{'id': v.id},
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveVisitCard extends StatelessWidget {
  const _ActiveVisitCard({required this.visit, required this.canRecord});

  final UnplannedVisit visit;
  final bool canRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.05),
            blurRadius: 20.r,
            spreadRadius: 2.r,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppColors.blue500.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_walk_rounded,
                    color: AppColors.blue500, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      visit.target.type.label,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      visit.target.displayName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 12.w,
                height: 12.h,
                decoration: const BoxDecoration(
                  color: AppColors.blue500,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          if (canRecord) ...<Widget>[
            SizedBox(height: 16.h),
            CustomButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => StopVisitSheet(visit: visit),
              ),
              label: 'Complete Visit ->',
              backgroundColor: AppColors.red500,
            ),
          ],
        ],
      ),
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
      SnackbarUtils.showWarning(context, e.message);
    } on UnplannedVisitConflictException catch (e) {
      if (!mounted) return;
      ref.invalidate(unplannedVisitsTodayProvider);
      SnackbarUtils.showInfo(context, e.message);
    } on Exception catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(context, userMessageFor(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      onPressed: _start,
      isLoading: _isLoading,
      label: 'Start New Visit',
      leadingIcon: Icons.add_location_alt_outlined,
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 32.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.pin_drop_outlined,
              color: AppColors.textHint, size: 48.sp),
          SizedBox(height: 16.h),
          Text(
            'No visits recorded today',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
