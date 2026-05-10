import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/auth/biometric_preference.dart';
import 'package:sales_sphere_erp/core/auth/biometric_service.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// One-shot wrapper that fires the post-first-login biometric setup
/// prompt. Mounts as part of `HomeShell`, so it lives for the duration
/// of an authenticated session — `initState` runs once on fresh login
/// or cold-start success, never again on tab navigation.
///
/// Only prompts when the user's preference is `unset` AND the device
/// has biometric hardware enrolled. After the user's choice, the
/// preference becomes `enabled` or `declined` and this widget is a
/// passthrough on subsequent mounts (until they explicitly clear it).
class BiometricSetupGate extends ConsumerStatefulWidget {
  const BiometricSetupGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BiometricSetupGate> createState() =>
      _BiometricSetupGateState();
}

class _BiometricSetupGateState extends ConsumerState<BiometricSetupGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferSetup());
  }

  Future<void> _maybeOfferSetup() async {
    if (_checked) return;
    _checked = true;

    final pref = await ref.read(biometricPreferenceProvider).read();
    if (pref != BiometricPrefState.unset) return;

    final available = await ref.read(biometricServiceProvider).isAvailable;
    if (!available) return;

    if (!mounted) return;

    final wantsEnable = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => const _BiometricSetupSheet(),
    );

    if (!mounted) return;

    if (wantsEnable != true) {
      // Tapped "Not now" or dismissed via the close handle.
      await ref.read(biometricPreferenceProvider).setEnabled(value: false);
      return;
    }

    final ok = await ref.read(biometricServiceProvider).authenticate(
          localizedReason: 'Confirm biometric unlock',
        );
    await ref.read(biometricPreferenceProvider).setEnabled(value: ok);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BiometricSetupSheet extends StatelessWidget {
  const _BiometricSetupSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 24.h),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 72.r,
                height: 72.r,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22.r),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.fingerprint,
                  size: 40.sp,
                  color: AppColors.secondary,
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Enable biometric unlock?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Use your fingerprint to sign in faster next time. '
              'You can change this anytime under More → Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: 28.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedCustomButton(
                    label: 'Not now',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: PrimaryButton(
                    label: 'Enable',
                    leadingIcon: Icons.fingerprint,
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
