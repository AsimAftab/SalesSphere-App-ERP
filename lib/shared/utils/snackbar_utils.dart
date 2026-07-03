import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Modern Snackbar Utility
/// Provides clean, beautiful snackbars with different variants
class SnackbarUtils {
  SnackbarUtils._();

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: AppColors.success,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.error_rounded,
      backgroundColor: AppColors.error,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.warning_rounded,
      backgroundColor: AppColors.warning,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.info_rounded,
      backgroundColor: AppColors.info,
      duration: duration,
    );
  }

  /// Success snackbar with a trailing action button (e.g. "Open" after a
  /// file is saved). Uses the same styling pipeline as the other variants
  /// so the look stays consistent. Defaults to a longer duration so the
  /// user has time to reach for the action.
  static void showSuccessWithAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration duration = const Duration(seconds: 6),
  }) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: AppColors.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Error snackbar with a trailing action button (e.g. "Settings" for
  /// permission-denied flows). Uses the same styling pipeline as the
  /// other variants so the look stays consistent.
  static void showErrorWithAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    _showSnackbar(
      context,
      message: message,
      icon: Icons.error_rounded,
      backgroundColor: AppColors.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Info snackbar bound to an already-resolved [ScaffoldMessengerState].
  static void showInfoOn(
    ScaffoldMessengerState messenger,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _present(
      messenger,
      message: message,
      icon: Icons.info_rounded,
      backgroundColor: AppColors.info,
      duration: duration,
    );
  }

  /// Error snackbar bound to an already-resolved [ScaffoldMessengerState].
  static void showErrorOn(
    ScaffoldMessengerState messenger,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _present(
      messenger,
      message: message,
      icon: Icons.error_rounded,
      backgroundColor: AppColors.error,
      duration: duration,
    );
  }

  /// Success + action snackbar bound to a resolved [ScaffoldMessengerState].
  /// Use this (over [showSuccessWithAction]) when the result is shown after
  /// an async gap — the messenger survives the originating widget's disposal.
  static void showSuccessWithActionOn(
    ScaffoldMessengerState messenger,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration duration = const Duration(seconds: 6),
  }) {
    _present(
      messenger,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: AppColors.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Error + action snackbar bound to a resolved [ScaffoldMessengerState].
  static void showErrorWithActionOn(
    ScaffoldMessengerState messenger,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    _present(
      messenger,
      message: message,
      icon: Icons.error_rounded,
      backgroundColor: AppColors.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void _showSnackbar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _present(
      ScaffoldMessenger.of(context),
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Messenger-based core. Capturing a [ScaffoldMessengerState] up front
  /// (via the `...On` variants) lets a caller show a result *after* an async
  /// gap even when the widget that kicked off the work has since been
  /// disposed — e.g. a history row that scrolled off or rebuilt while the
  /// PDF was generating. `ScaffoldMessenger.of(context)` would be unusable
  /// by then, so the message would silently never appear.
  static void _present(
    ScaffoldMessengerState messenger, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    messenger.clearSnackBars();

    final snackBar = SnackBar(
      content: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.fixed,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      elevation: 4,
      dismissDirection: DismissDirection.horizontal,
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction,
            )
          : null,
    );

    messenger.showSnackBar(snackBar);
  }
}
