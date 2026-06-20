import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Shown when the user taps Check Out before the full-day window opens but
/// while the half-day window is open: offers a half-day checkout as a
/// fallback (mirrors the v1 app's "Checkout Half-Day" flow). A normal,
/// end-of-day full-day checkout never sees this — it goes through directly.
///
/// Resolves to `true` when the user confirms half-day, `null` otherwise.
class HalfDayCheckoutDialog extends StatelessWidget {
  const HalfDayCheckoutDialog({
    required this.fullDayAvailableFrom,
    super.key,
  });

  /// Time (h:mm a) the full-day checkout window opens — shown so the user
  /// knows the alternative to checking out half-day now.
  final String fullDayAvailableFrom;

  static Future<bool?> show(
    BuildContext context, {
    required String fullDayAvailableFrom,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => HalfDayCheckoutDialog(
        fullDayAvailableFrom: fullDayAvailableFrom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14.sp,
      height: 1.5,
    );
    final bold = base.copyWith(fontWeight: FontWeight.w700);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: AppColors.surface,
      // Scrollable so the actions are always reachable, even on short screens
      // / large text scales.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── Orange header ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: AppColors.warning.withValues(alpha: 0.10),
              padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 56.r,
                    height: 56.r,
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
                      Icons.timelapse_rounded,
                      color: AppColors.warning,
                      size: 30.sp,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Full-Day Checkout Not Available',
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
            // ── Body ───────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 20.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      style: base,
                      children: <InlineSpan>[
                        const TextSpan(text: 'Full-day checkout opens at '),
                        TextSpan(text: fullDayAvailableFrom, style: bold),
                        const TextSpan(text: '. You can check out as '),
                        TextSpan(text: 'half-day', style: bold),
                        const TextSpan(text: ' now instead.'),
                      ],
                    ),
                  ),
                  SizedBox(height: 22.h),
                  // Full-width stacked actions — primary on top, cancel below.
                  PrimaryButton(
                    label: 'Checkout as Half-Day',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                  SizedBox(height: 10.h),
                  OutlinedCustomButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
