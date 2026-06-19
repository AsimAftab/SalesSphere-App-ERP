import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Info dialog shown when the server refuses a check-in (too early, window
/// closed, weekly-off, on-leave). The caller composes [title] + [message]
/// from the server's structured restriction details so this widget stays a
/// dumb presenter.
class CheckInNotAllowedDialog extends StatelessWidget {
  const CheckInNotAllowedDialog({
    required this.message,
    super.key,
    this.title = 'Check-In Not Allowed',
  });

  final String title;
  final String message;

  static Future<void> show(
    BuildContext context, {
    required String message,
    String title = 'Check-In Not Allowed',
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => CheckInNotAllowedDialog(message: message, title: title),
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
          // ── Red header ───────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.red500.withValues(alpha: 0.10),
            padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64.r,
                  height: 64.r,
                  decoration: BoxDecoration(
                    color: AppColors.red500.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.red500.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.access_time_rounded,
                    color: AppColors.red500,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  title,
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
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 24.h),
                PrimaryButton(
                  label: 'OK',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
