import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Shows the destructive "skip stop" confirmation. Returns `true` when the
/// user confirms, `false` (or null → false on dismiss) otherwise. Mirrors the
/// shared sign-out confirmation so destructive actions read consistently.
Future<bool> showSkipStopConfirmation(
  BuildContext context, {
  required String stopName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.primary.withValues(alpha: 0.45),
    builder: (_) => SkipStopConfirmationDialog(stopName: stopName),
  );
  return confirmed ?? false;
}

/// Confirmation card for skipping a route stop. Returns `true` when the user
/// taps "Skip", `false` (or null on dismiss) otherwise. Reads as a centred
/// card so the destructive action stays bounded and obvious.
class SkipStopConfirmationDialog extends StatelessWidget {
  const SkipStopConfirmationDialog({required this.stopName, super.key});

  final String stopName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Tinted error icon block — same red treatment used on the
            // skipped-status banner so the "destructive" signal stays
            // consistent across the app.
            Center(
              child: Container(
                width: 56.r,
                height: 56.r,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.block_rounded,
                  color: AppColors.error,
                  size: 28.sp,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Skip stop?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "Skip $stopName? This can't be undone.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
                height: 1.4,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedCustomButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: CustomButton(
                    label: 'Skip',
                    backgroundColor: AppColors.error,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
