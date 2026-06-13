import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A reusable, cleanly designed status badge (pill) that can be used across 
/// any feature in the application (Attendance, Tour Plans, Leave, etc.).
/// 
/// It automatically handles Skeletonizer loading states to prevent coloured 
/// chips from bleeding through the skeleton wash.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.color,
    this.backgroundColor,
    this.padding,
    this.fontSize,
    super.key,
  });

  /// The text displayed inside the badge.
  final String label;

  /// The primary color used for the text and optional icon.
  final Color color;

  /// The background color of the pill. 
  /// If null, it defaults to the primary [color] with 12% opacity.
  final Color? backgroundColor;


  /// Custom padding. Defaults to `horizontal: 10.w, vertical: 4.h`.
  final EdgeInsetsGeometry? padding;

  /// Custom font size. Defaults to `12.sp`.
  final double? fontSize;


  @override
  Widget build(BuildContext context) {
    // `Skeleton.replace` swaps the colored pill for a neutral bone
    // while the list is loading — without this, the tinted background
    // and bold-coloured text ignore the skeletonizer wash and read as
    // real content over a "loading" row.
    return Skeleton.replace(
      replacement: Bone(
        width: 72.w,
        height: 26.h,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Container(
        padding: padding ?? EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: backgroundColor ?? color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(40.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[

            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: fontSize ?? 12.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
