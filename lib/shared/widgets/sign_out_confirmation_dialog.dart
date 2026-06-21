import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Shows the shared destructive sign-out confirmation. Returns `true` when
/// the user confirms, `false` (or null → false on dismiss) otherwise.
/// Both Settings and Profile call this so the sign-out flow stays identical.
Future<bool> showSignOutConfirmation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.primary.withValues(alpha: 0.45),
    builder: (_) => const SignOutConfirmationDialog(),
  );
  return confirmed ?? false;
}

/// Confirmation card for the destructive sign-out action. Returns
/// `true` when the user taps "Sign Out", `false` (or null on dismiss)
/// otherwise. Reads as a centred card rather than a full-width sheet
/// so the destructive action stays bounded and obvious.
class SignOutConfirmationDialog extends StatelessWidget {
  const SignOutConfirmationDialog({super.key});

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
            // detail-page status banner so the visual signal for
            // "destructive" stays consistent across the app.
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
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 28.sp,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Sign out?',
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
              "You'll need to sign back in to access your account.",
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
                  child: PrimaryButton(
                    label: 'Sign Out',
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
