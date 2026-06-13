import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Why check-in was denied — drives the copy inside the dialog.
enum CheckInDeniedReason {
  /// The day is a weekly off.
  weeklyOff,

  /// The check-in window has already closed.
  tooLate,
}

/// Modal dialog shown when a user taps Check-In outside the allowed window
/// or on a weekly-off day.
///
/// Usage:
/// ```dart
/// CheckInNotAllowedDialog.show(
///   context,
///   reason: CheckInDeniedReason.weeklyOff,
///   weekdayName: 'Saturday',
/// );
/// ```
class CheckInNotAllowedDialog extends StatelessWidget {
  const CheckInNotAllowedDialog({
    super.key,
    required this.reason,
    this.weekdayName,
    this.allowedFrom,
    this.allowedUntil,
  });

  final CheckInDeniedReason reason;

  /// Day name — only used when [reason] is [CheckInDeniedReason.weeklyOff].
  final String? weekdayName;

  /// Window open time string (HH:MM) — used when [reason] is [CheckInDeniedReason.tooLate].
  final String? allowedFrom;

  /// Window close time string (HH:MM) — used when [reason] is [CheckInDeniedReason.tooLate].
  final String? allowedUntil;

  static Future<void> show(
    BuildContext context, {
    required CheckInDeniedReason reason,
    String? weekdayName,
    String? allowedFrom,
    String? allowedUntil,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CheckInNotAllowedDialog(
        reason: reason,
        weekdayName: weekdayName,
        allowedFrom: allowedFrom,
        allowedUntil: allowedUntil,
      ),
    );
  }

  /// Returns a [Widget] with the description text. Times in the `tooLate`
  /// variant are bolded so the user can immediately see the window they missed.
  Widget _bodyWidget(BuildContext context) {
    final base = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 13.sp,
      height: 1.5,
    );
    final bold = base.copyWith(fontWeight: FontWeight.w700);

    switch (reason) {
      case CheckInDeniedReason.weeklyOff:
        final day = weekdayName ?? 'today';
        return Text(
          "Today is $day, the organisation's weekly off day. "
          'You cannot check in on this day.',
          textAlign: TextAlign.left,
          style: base,
        );
      case CheckInDeniedReason.tooLate:
        final from = allowedFrom ?? '--:--';
        final until = allowedUntil ?? '--:--';
        return Text.rich(
          TextSpan(
            style: base,
            children: <InlineSpan>[
              const TextSpan(text: 'The check-in window has closed. '
                  'Check-in was allowed between '),
              TextSpan(text: from, style: bold),
              const TextSpan(text: ' and '),
              TextSpan(text: until, style: bold),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.left,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      // clipBehavior ensures the red header respects the dialog's rounded corners.
      clipBehavior: Clip.antiAlias,
      backgroundColor: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── Red header — full width ──────────────────────────────────────
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
                  'Check-In Not Allowed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          // ── White body — description + OK ────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _bodyWidget(context),
                SizedBox(height: 24.h),
                PrimaryButton(
                  label: 'OK',
                  size: ButtonSize.medium,
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
