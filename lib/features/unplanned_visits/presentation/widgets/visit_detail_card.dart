import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/visit_formatting.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/widgets/visit_times_strip.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/status_badge.dart';
import 'package:url_launcher/url_launcher.dart';

/// Consolidated "entity visit" card — the beat-plan route-stop card adapted for
/// unplanned visits. Because the geofence ties the visit to the target's
/// location there's a single location (the entity's): one map/directions
/// action, a Started/Ended/Duration strip, then the captured-at-stop notes,
/// follow-up and proof photo (photo last).
class VisitDetailCard extends StatelessWidget {
  const VisitDetailCard({required this.visit, super.key});

  final UnplannedVisit visit;

  Color get _typeColor => switch (visit.target.type) {
    VisitTargetType.prospect => AppColors.warning,
    VisitTargetType.site => AppColors.green500,
    VisitTargetType.customer => AppColors.blue500,
  };

  Future<void> _openMaps(BuildContext context) async {
    final lat = visit.target.latitude ?? visit.startLocation?.latitude;
    final lng = visit.target.longitude ?? visit.startLocation?.longitude;
    if (lat == null || lng == null) {
      SnackbarUtils.showInfo(context, 'No location recorded for this visit.');
      return;
    }
    final geo = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final web = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await _launch(context, primary: geo, fallback: web);
  }

  Future<void> _openDirections(BuildContext context) async {
    final lat = visit.target.latitude ?? visit.startLocation?.latitude;
    final lng = visit.target.longitude ?? visit.startLocation?.longitude;
    if (lat == null || lng == null) {
      SnackbarUtils.showInfo(context, 'No location recorded for this visit.');
      return;
    }
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    await _launch(context, primary: url, fallback: url);
  }

  Future<void> _launch(
    BuildContext context, {
    required Uri primary,
    required Uri fallback,
  }) async {
    try {
      if (await canLaunchUrl(primary)) {
        await launchUrl(primary);
        return;
      }
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    } on Exception catch (_) {
      if (!context.mounted) return;
      SnackbarUtils.showError(context, "Couldn't open Maps.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = visit.isInProgress;
    final initial = visit.target.displayName.isNotEmpty
        ? visit.target.displayName[0].toUpperCase()
        : '?';
    final address = visit.target.address?.trim();
    final description = (visit.description ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Header: avatar + type badge, name, status, address ────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 26.r,
                      backgroundColor: _typeColor,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: _typeColor,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        visit.target.type.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              visit.target.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          StatusBadge(
                            label: active ? 'On Visit' : 'Completed',
                            color: active
                                ? AppColors.blue500
                                : AppColors.green500,
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.location_on_outlined,
                            size: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              address?.isNotEmpty ?? false
                                  ? address!
                                  : 'No address on record',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            // ── Map / Directions actions ──────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: _OutlineAction(
                    icon: Icons.map_outlined,
                    label: 'View Map',
                    color: AppColors.primary,
                    onTap: () => _openMaps(context),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _OutlineAction(
                    icon: Icons.directions_outlined,
                    label: 'Directions',
                    color: AppColors.green500,
                    onTap: () => _openDirections(context),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            // ── Times strip ───────────────────────────────────────────────
            VisitTimesStrip(visit: visit),
            // ── Captured-at-stop details (completed visits only): notes,
            //    follow-up, then the proof photo LAST — each separated by a
            //    light divider so the blocks read distinctly. ───────────────
            if (!active) ...<Widget>[
              SizedBox(height: 16.h),
              _divider(),
              SizedBox(height: 16.h),
              _Labelled(
                icon: Icons.sticky_note_2_outlined,
                label: 'Description',
                value: description.isEmpty ? null : description,
                emptyText: 'No description added',
              ),
              SizedBox(height: 14.h),
              _divider(),
              SizedBox(height: 14.h),
              _Labelled(
                icon: Icons.event_repeat_rounded,
                label: 'Follow-up Date',
                value: visit.followUpDate == null
                    ? null
                    : formatVisitDate(visit.followUpDate),
                emptyText: 'No follow-up scheduled',
                valueColor: AppColors.primary,
              ),
              SizedBox(height: 14.h),
              _divider(),
              SizedBox(height: 14.h),
              _PhotoSection(url: visit.imageUrl),
            ],
          ],
        ),
      ),
    );
  }
}

/// A hairline separator between the captured-detail blocks.
Widget _divider() =>
    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6));

/// A captioned detail block: a small label over a value, with a muted
/// placeholder when the value is absent — keeps Description / Follow-up reading
/// uniformly whether or not they were filled in.
class _Labelled extends StatelessWidget {
  const _Labelled({
    required this.icon,
    required this.label,
    required this.value,
    required this.emptyText,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String emptyText;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 16.sp, color: AppColors.textSecondary),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          hasValue ? value! : emptyText,
          style: TextStyle(
            color: hasValue ? (valueColor ?? AppColors.textPrimary) : AppColors.textHint,
            fontSize: 14.sp,
            fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
            fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// The proof photo block — captioned, shown last. Falls back to a muted
/// placeholder if no photo is attached.
class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.image_outlined,
              size: 16.sp,
              color: AppColors.textSecondary,
            ),
            SizedBox(width: 8.w),
            Text(
              'Photo',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        if (url != null)
          _ZoomableImage(url: url!)
        else
          Container(
            height: 96.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.textHint,
                  size: 24.sp,
                ),
                SizedBox(height: 6.h),
                Text(
                  'No photo attached',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Outlined pill action button (View Map / Directions).
class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.2),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16.sp, color: color),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable, zoomable proof photo.
class _ZoomableImage extends StatelessWidget {
  const _ZoomableImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showViewer(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
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
              child: Icon(
                Icons.broken_image_rounded,
                color: AppColors.textHint,
                size: 28.sp,
              ),
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
          children: <Widget>[
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
