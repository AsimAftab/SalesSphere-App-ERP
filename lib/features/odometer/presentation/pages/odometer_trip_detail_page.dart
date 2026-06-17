import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/auth/permissions.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/controllers/odometer_controller.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/odometer_formatting.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/providers/odometer_providers.dart';
import 'package:sales_sphere_erp/shared/utils/error_messages.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:url_launcher/url_launcher.dart';

class OdometerTripDetailPage extends ConsumerWidget {
  const OdometerTripDetailPage({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(odometerTripByIdProvider(tripId));
    final canDelete = ref.watch(hasPermissionProvider(Permissions.odometerDelete));

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
            'Trip Details',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (canDelete)
              tripAsync.maybeWhen(
                data: (trip) => IconButton(
                  tooltip: 'Delete trip',
                  icon: Icon(Icons.delete_outline_rounded,
                      color: AppColors.red500, size: 22.sp),
                  onPressed: () => _confirmDelete(context, ref, trip),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
          ],
        ),
        body: tripAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text(
              "Couldn't load this trip",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          data: (trip) => _TripDetailBody(trip: trip),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    OdometerTrip trip,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: Text(
          'Trip #${trip.tripNumber} and its photos will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red500),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(odometerControllerProvider.notifier)
          .deleteTrip(trip.id, tripDate: trip.date);
      if (!context.mounted) return;
      SnackbarUtils.showSuccess(context, 'Trip deleted.');
      context.pop();
    } on Exception catch (e) {
      if (!context.mounted) return;
      SnackbarUtils.showError(context, userMessageFor(e));
    }
  }
}

class _TripDetailBody extends StatelessWidget {
  const _TripDetailBody({required this.trip});

  final OdometerTrip trip;

  @override
  Widget build(BuildContext context) {
    final unit = trip.distanceUnit.label;
    final isActive = trip.isInProgress;

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trip #${trip.tripNumber}',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isActive)
              const StatusBadge(label: 'Active', color: AppColors.blue500)
            else
              const StatusBadge(
                  label: 'Completed', color: AppColors.green500),
          ],
        ),
        if (trip.date != null) ...[
          SizedBox(height: 4.h),
          Text(
            DateFormat('EEEE, d MMM yyyy').format(trip.date!),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        SizedBox(height: 20.h),
        Row(
          children: [
            Expanded(
              child: _MetricBox(
                label: 'Start',
                value: formatReading(trip.startReading),
                unit: unit,
                color: AppColors.blue500,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _MetricBox(
                label: 'Stop',
                value: isActive ? '---' : formatReading(trip.stopReading),
                unit: unit,
                color: AppColors.red500,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _MetricBox(
                label: 'Distance',
                value: isActive ? '...' : formatReading(trip.distance),
                unit: unit,
                color: AppColors.green500,
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),
        _LegCard(
          title: 'Start',
          icon: Icons.play_circle_fill_rounded,
          accent: AppColors.blue500,
          time: trip.startedAt,
          description: trip.startDescription,
          imageUrl: trip.startImageUrl,
          location: trip.startLocation,
        ),
        if (!isActive) ...[
          SizedBox(height: 16.h),
          _LegCard(
            title: 'Stop',
            icon: Icons.stop_circle_rounded,
            accent: AppColors.red500,
            time: trip.stoppedAt,
            description: trip.stopDescription,
            imageUrl: trip.stopImageUrl,
            location: trip.stopLocation,
          ),
        ],
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegCard extends StatelessWidget {
  const _LegCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.time,
    required this.description,
    required this.imageUrl,
    required this.location,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final DateTime? time;
  final String? description;
  final String? imageUrl;
  final TripLocation? location;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (time != null)
                Text(
                  DateFormat('d MMM, hh:mm a').format(time!),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (imageUrl != null) ...[
            SizedBox(height: 12.h),
            _ZoomableImage(url: imageUrl!),
          ],
          if (location != null) ...[
            SizedBox(height: 12.h),
            _LocationRow(location: location!),
          ],
          if (description != null && description!.trim().isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              description!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.sp,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatelessWidget {
  const _ZoomableImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showViewer(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: CachedNetworkImage(
          imageUrl: url,
          height: 180.h,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            height: 180.h,
            color: AppColors.background,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 180.h,
            color: AppColors.background,
            child: Center(
              child: Icon(Icons.broken_image_rounded,
                  color: AppColors.textHint, size: 28.sp),
            ),
          ),
        ),
      ),
    );
  }

  void _showViewer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(12.w),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location});

  final TripLocation location;

  @override
  Widget build(BuildContext context) {
    final label = location.address ??
        '${location.latitude.toStringAsFixed(5)}, '
            '${location.longitude.toStringAsFixed(5)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on_rounded,
            color: AppColors.textSecondary, size: 18.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
              height: 1.3,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () => _openInMaps(location.latitude, location.longitude),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_rounded, color: AppColors.blue500, size: 16.sp),
              SizedBox(width: 4.w),
              Text(
                'Maps',
                style: TextStyle(
                  color: AppColors.blue500,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
