import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/auth/biometric_preference.dart';
import 'package:sales_sphere_erp/core/auth/biometric_service.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Account-level settings reached from More → Settings. Carries the
/// Profile entry (drills into `/profile`), the biometric-unlock
/// toggle, and the destructive Sign-out action. Future settings
/// (notifications, language, theme) join the existing sections — or
/// take a new section.
///
/// Chrome mirrors the parties / prospects / sites / visit-notes list
/// pages — corner-bubble decoration behind a custom `_AppBar` — minus
/// the search bar (no list to filter), so the page reads as part of
/// the same family even though the body is a static settings list.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final enabled = await ref.read(biometricPreferenceProvider).isEnabled();
    final available = await ref.read(biometricServiceProvider).isAvailable;
    if (!mounted) return;
    setState(() {
      _biometricEnabled = enabled;
      _biometricAvailable = available;
      _loading = false;
    });
  }

  Future<void> _toggleBiometric(bool next) async {
    if (_busy) return;
    setState(() => _busy = true);

    if (next) {
      // Enabling — confirm with a real biometric prompt so we know the
      // hardware actually works on this device.
      final ok = await ref.read(biometricServiceProvider).authenticate(
            localizedReason: 'Confirm biometric unlock',
          );
      if (!mounted) return;
      if (!ok) {
        // Cancelled or failed — leave the toggle off.
        setState(() => _busy = false);
        SnackbarUtils.showInfo(context, 'Biometric unlock not enabled.');
        return;
      }
      await ref.read(biometricPreferenceProvider).setEnabled(value: true);
    } else {
      await ref.read(biometricPreferenceProvider).setEnabled(value: false);
    }

    if (!mounted) return;
    setState(() {
      _biometricEnabled = next;
      _busy = false;
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.more);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: <Widget>[
                        _AppBar(onBack: _back),
                        SizedBox(height: 24.h),
                        Expanded(
                          child: ListView(
                            padding:
                                EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                            children: <Widget>[
                              const _SectionLabel(label: 'Account'),
                              SizedBox(height: 8.h),
                              _NavRow(
                                icon: Icons.person_outline,
                                title: 'Profile',
                                onTap: () => context.push(Routes.profile),
                              ),
                              SizedBox(height: 24.h),
                              const _SectionLabel(label: 'Security'),
                              SizedBox(height: 8.h),
                              _BiometricRow(
                                enabled: _biometricEnabled,
                                available: _biometricAvailable,
                                busy: _busy,
                                onChanged: _toggleBiometric,
                              ),
                              SizedBox(height: 32.h),
                              _SignOutRow(onTap: _signOut),
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
/// visit-notes list pages — back arrow on the left, page title in
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Single-line navigation row — icon block + title + chevron, soft
/// shadow, 20.r radius. Reserved for entries that drill into another
/// page; the absence of a subtitle keeps these compact and signals
/// "tap to go" rather than "configurable here".
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
      borderRadius: BorderRadius.circular(20.r),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
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
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: AppColors.secondary,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
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

/// Biometric-unlock row — same chrome as [_NavRow] but two-line (the
/// subtitle explains availability) and ends with [_AppToggle] instead
/// of a chevron.
class _BiometricRow extends StatelessWidget {
  const _BiometricRow({
    required this.enabled,
    required this.available,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool available;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final disabled = !available || busy;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: <Widget>[
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.fingerprint,
                color: AppColors.secondary,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Biometric unlock',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    available
                        ? 'Use your fingerprint to sign in faster.'
                        : 'No biometric hardware enrolled on this device.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            _AppToggle(
              value: enabled,
              onChanged: disabled ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// Brand-themed pill switch. Reads more "polished" than the default
/// Material switch on Android — flat secondary track when on, soft
/// border-grey track when off, white thumb either way with a subtle
/// shadow. The default Switch.adaptive renders a stockier widget with
/// a coloured thumb; this trades that for a lighter visual that
/// matches the rest of the settings chrome.
class _AppToggle extends StatelessWidget {
  const _AppToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => onChanged!(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 46.w,
          height: 26.h,
          padding: EdgeInsets.all(2.r),
          decoration: BoxDecoration(
            color: value
                ? AppColors.secondary
                : AppColors.border.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(40.r),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22.r,
              height: 22.r,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Destructive sign-out row. Same chrome as [_NavRow] but red-tinted —
/// red icon block, red label, hairline red border — so it reads as a
/// commit action instead of a navigation. No chevron: tapping signs
/// out, it doesn't drill into a page.
class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20.r),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.25),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.r),
          splashColor: AppColors.error.withValues(alpha: 0.12),
          highlightColor: AppColors.error.withValues(alpha: 0.06),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.logout,
                    color: AppColors.error,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text(
                    'Sign out',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
