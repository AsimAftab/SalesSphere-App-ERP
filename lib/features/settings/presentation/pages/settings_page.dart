import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Account-level settings reached from More → Settings. Two sections:
/// Personal (Profile + Change Password) and Other Settings (about,
/// terms, sign out). Rows are uniform — neutral outline icon, title,
/// chevron — so the page reads as a flat list of destinations.
///
/// Chrome mirrors the parties / prospects / sites / notes list pages —
/// corner-bubble decoration behind a custom `_AppBar` — so settings
/// sits inside the same visual vocabulary even though the body is a
/// static settings list.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.more);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.primary.withValues(alpha: 0.45),
      builder: (_) => const _SignOutConfirmationDialog(),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).logout();
  }

  /// Placeholder tap handler for entries that don't have a destination
  /// wired yet. The snackbar's neutral tone (info, not error) reads as
  /// a deliberate "not yet" rather than a failure.
  void _comingSoon(BuildContext context, String label) {
    SnackbarUtils.showInfo(context, '$label — coming soon.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SvgPicture.asset(
                'assets/images/corner_bubble.svg',
                fit: BoxFit.cover,
                height: 180.h,
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _AppBar(onBack: () => _back(context)),
                  SizedBox(height: 24.h),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                      children: <Widget>[
                        const _SectionLabel(label: 'Personal'),
                        SizedBox(height: 12.h),
                        _NavRow(
                          icon: Icons.person_outline,
                          title: 'Profile',
                          onTap: () => context.push(Routes.profile),
                        ),
                        SizedBox(height: 12.h),
                        _NavRow(
                          icon: Icons.lock_outline,
                          title: 'Change Password',
                          onTap: () => _comingSoon(context, 'Change Password'),
                        ),
                        SizedBox(height: 28.h),
                        const _SectionLabel(label: 'Other Settings'),
                        SizedBox(height: 12.h),
                        _NavRow(
                          icon: Icons.info_outline,
                          title: 'About Sales Sphere',
                          onTap: () =>
                              _comingSoon(context, 'About Sales Sphere'),
                        ),
                        SizedBox(height: 12.h),
                        _NavRow(
                          icon: Icons.description_outlined,
                          title: 'Terms and Conditions',
                          onTap: () =>
                              _comingSoon(context, 'Terms and Conditions'),
                        ),
                        SizedBox(height: 12.h),
                        _NavRow(
                          icon: Icons.logout_outlined,
                          title: 'Sign Out',
                          onTap: () => _signOut(context, ref),
                        ),
                      ],
                    ),
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

/// Mirrors the `_AppBar` used on parties / prospects / sites /
/// notes list pages — back arrow on the left, page title in
/// primary 20sp w600 — so settings sits inside the same visual
/// vocabulary even though it isn't a list-driven screen.
class _AppBar extends StatelessWidget {
  const _AppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textdark,
              size: 20.sp,
            ),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          SizedBox(width: 12.w),
          Text(
            'Settings',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mixed-case section header (matches the design spec: "Personal",
/// "Other Settings"). Sits flush-left and reads as a label, not a
/// shouting all-caps tag.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Single-line navigation row — neutral outline icon + title +
/// chevron, soft shadow, 16.r radius. No coloured icon block per the
/// design spec; the icon sits inline so the row reads as a flat menu
/// entry. Sign Out shares this chrome so the section reads as a
/// uniform stack.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16.r),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
            child: Row(
              children: <Widget>[
                Icon(icon, color: AppColors.textPrimary, size: 22.sp),
                SizedBox(width: 16.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 22.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirmation card for the destructive sign-out action. Returns
/// `true` when the user taps "Sign Out", `false` (or null on dismiss)
/// otherwise. Reads as a centred card rather than a full-width sheet
/// so the destructive action stays bounded and obvious.
class _SignOutConfirmationDialog extends StatelessWidget {
  const _SignOutConfirmationDialog();

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
