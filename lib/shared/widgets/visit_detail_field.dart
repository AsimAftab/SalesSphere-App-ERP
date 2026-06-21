import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';

/// A hairline separator between captioned detail blocks.
Widget visitDetailDivider() =>
    Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6));

/// A captioned detail block: a small label over a value, with a muted
/// placeholder when the value is absent — keeps fields like Description /
/// Follow-up reading uniformly whether or not they were filled in. Shared by
/// the unplanned-visit detail card and the beat-plan route-stop card so both
/// render these fields identically.
class VisitDetailField extends StatelessWidget {
  const VisitDetailField({
    required this.icon,
    required this.label,
    required this.value,
    required this.emptyText,
    this.valueColor,
    super.key,
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
            color: hasValue
                ? (valueColor ?? AppColors.textPrimary)
                : AppColors.textHint,
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

/// A captioned proof-photo block: a "Photo" label over the tappable, zoomable
/// image, or a muted "No photo attached" placeholder when none was captured.
class VisitDetailPhoto extends StatelessWidget {
  const VisitDetailPhoto({required this.url, super.key});

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

/// A tappable proof photo — opens the shared full-screen zoom preview.
class _ZoomableImage extends StatelessWidget {
  const _ZoomableImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          showPrimaryImagePreview(context, CachedNetworkImageProvider(url)),
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
}
