import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Modal shown when a field-ops action (starting an unplanned visit, an
/// odometer trip, …) is blocked because the rep hasn't checked in (marked
/// attendance) for the day — either the backend's `422 NOT_CHECKED_IN` or a
/// proactive client-side check before opening a form.
///
/// Uses the brand-blue header (an actionable prompt, not an orange warning).
/// [show] resolves to `true` when the rep taps "Check In", so the caller can
/// route to the attendance screen.
class CheckInRequiredDialog extends StatelessWidget {
  const CheckInRequiredDialog({required this.message, super.key});

  /// The reason copy, e.g. "You must check in (attendance) before starting a
  /// trip" — usually the backend's message, or a sensible default for the
  /// proactive check.
  final String message;

  static Future<bool?> show(BuildContext context, {required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CheckInRequiredDialog(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── Blue header ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.blue500.withValues(alpha: 0.10),
            padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64.r,
                  height: 64.r,
                  decoration: BoxDecoration(
                    color: AppColors.blue500.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.blue500.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.how_to_reg_rounded,
                    color: AppColors.blue500,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Check In Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 24.h),
                PrimaryButton(
                  label: 'Check In',
                  leadingIcon: Icons.login_rounded,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                SizedBox(height: 10.h),
                CustomButton(
                  label: 'Not Now',
                  type: ButtonType.text,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
