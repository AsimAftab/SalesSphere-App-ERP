import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Modal dialog shown when the user taps Check-Out before the allowed window
/// opens. Mirrors the design in Screenshot 2:
///   - Orange clock icon
///   - "Checkout Not Allowed Yet" title
///   - Body copy explaining both the full-day and half-day windows
///   - Info card with Scheduled Checkout / Allowed From / Checkout Type rows
///
/// Usage:
/// ```dart
/// CheckoutNotAllowedDialog.show(
///   context,
///   scheduledCheckOut: '18:00',
///   fullDayAllowedFrom: '17:30',
///   halfDayAvailableAt: '12:45',
/// );
/// ```
class CheckoutNotAllowedDialog extends StatelessWidget {
  const CheckoutNotAllowedDialog({
    required this.scheduledCheckOut,
    required this.fullDayAllowedFrom,
    required this.halfDayAvailableAt,
    super.key,
  });

  /// Scheduled full-day checkout time string (HH:MM) — shown in the info card.
  final String scheduledCheckOut;

  /// Earliest time full-day checkout is permitted (HH:MM).
  final String fullDayAllowedFrom;

  /// Earliest time half-day checkout is permitted (HH:MM).
  final String halfDayAvailableAt;

  static Future<void> show(
    BuildContext context, {
    required String scheduledCheckOut,
    required String fullDayAllowedFrom,
    required String halfDayAvailableAt,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => CheckoutNotAllowedDialog(
        scheduledCheckOut: scheduledCheckOut,
        fullDayAllowedFrom: fullDayAllowedFrom,
        halfDayAvailableAt: halfDayAvailableAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14.sp,
      height: 1.5,
    );
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      clipBehavior: Clip.antiAlias,
      backgroundColor: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── Orange header — full width ───────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.warning.withValues(alpha: 0.10),
            padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64.r,
                  height: 64.r,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.access_time_rounded,
                    color: AppColors.warning,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Checkout Not Allowed Yet',
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
          // ── White body — description + info card + OK ────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    style: baseStyle,
                    children: <InlineSpan>[
                      const TextSpan(text: 'You can only check out after '),
                      TextSpan(text: fullDayAllowedFrom, style: boldStyle),
                      const TextSpan(text: '. Half-day checkout becomes available at '),
                      TextSpan(text: halfDayAvailableAt, style: boldStyle),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.left,
                ),
                SizedBox(height: 16.h),
                // Info card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _InfoRow(
                        icon: Icons.access_time_rounded,
                        iconColor: AppColors.textSecondary,
                        label: 'Scheduled Checkout:',
                        value: scheduledCheckOut,
                      ),
                      SizedBox(height: 10.h),
                      _InfoRow(
                        icon: Icons.check_circle_outline,
                        iconColor: AppColors.green500,
                        label: 'Allowed From:',
                        value: fullDayAllowedFrom,
                        valueColor: AppColors.green500,
                      ),
                      SizedBox(height: 10.h),
                      const _InfoRow(
                        icon: Icons.info_outline,
                        iconColor: AppColors.textSecondary,
                        label: 'Checkout Type:',
                        value: 'full-day',
                      ),
                    ],
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

/// Single labelled row inside the info card.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 15.sp, color: iconColor),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
