import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/auth/permissions.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/controllers/unplanned_visit_controller.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/providers/unplanned_visit_providers.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/visit_formatting.dart';
import 'package:sales_sphere_erp/shared/utils/error_messages.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class UnplannedVisitDetailPage extends ConsumerWidget {
  const UnplannedVisitDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitAsync = ref.watch(unplannedVisitByIdProvider(id));
    final canDelete =
        ref.watch(hasPermissionProvider(Permissions.unplannedVisitDelete));

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: AppColors.textPrimary, size: 20.sp),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Visit Details',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: <Widget>[
            if (canDelete)
              visitAsync.maybeWhen(
                data: (visit) => IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: AppColors.red500, size: 22.sp),
                  tooltip: 'Delete visit',
                  onPressed: () => _confirmDelete(context, ref, visit),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
          ],
        ),
        body: visitAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Text(
                "Couldn't load this visit.",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
          data: (visit) => _Body(visit: visit),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    UnplannedVisit visit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete visit?'),
        content: Text('This removes the visit to ${visit.target.displayName}.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.red500),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(unplannedVisitControllerProvider.notifier)
          .deleteVisit(visit.id);
      if (!context.mounted) return;
      SnackbarUtils.showSuccess(context, 'Visit deleted.');
      context.pop();
    } on Exception catch (e) {
      if (!context.mounted) return;
      SnackbarUtils.showError(context, userMessageFor(e));
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.visit});

  final UnplannedVisit visit;

  @override
  Widget build(BuildContext context) {
    final active = visit.isInProgress;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      visit.target.displayName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      visit.target.type.label,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: active ? 'On Visit' : 'Completed',
                color: active ? AppColors.blue500 : AppColors.green500,
              ),
            ],
          ),
          if (visit.imageUrl != null) ...<Widget>[
            SizedBox(height: 20.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: CachedNetworkImage(
                imageUrl: visit.imageUrl!,
                fit: BoxFit.cover,
                height: 200.h,
                width: double.infinity,
                placeholder: (_, __) => Container(
                  height: 200.h,
                  color: AppColors.surface,
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 200.h,
                  color: AppColors.surface,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined,
                      color: AppColors.textHint, size: 40.sp),
                ),
              ),
            ),
          ],
          SizedBox(height: 20.h),
          _InfoCard(
            children: <Widget>[
              _InfoRow(
                icon: Icons.play_circle_outline_rounded,
                label: 'Started',
                value: formatVisitTime(visit.startedAt),
              ),
              if (visit.startLocation?.address != null)
                _InfoRow(
                  icon: Icons.my_location_rounded,
                  label: 'Start location',
                  value: visit.startLocation!.address!,
                ),
              if (visit.stoppedAt != null)
                _InfoRow(
                  icon: Icons.stop_circle_outlined,
                  label: 'Completed',
                  value: formatVisitTime(visit.stoppedAt),
                ),
              if (visit.stopLocation?.address != null)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'End location',
                  value: visit.stopLocation!.address!,
                ),
              if (visit.durationSeconds != null)
                _InfoRow(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: formatVisitDuration(visit.durationSeconds),
                ),
              if (visit.followUpDate != null)
                _InfoRow(
                  icon: Icons.event_rounded,
                  label: 'Follow-up',
                  value: formatVisitDate(visit.followUpDate),
                ),
            ],
          ),
          if ((visit.description ?? '').isNotEmpty) ...<Widget>[
            SizedBox(height: 20.h),
            Text(
              'Description',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                visit.description!,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.blue500, size: 18.sp),
          SizedBox(width: 12.w),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
