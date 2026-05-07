import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/auth/biometric_preference.dart';
import 'package:sales_sphere_erp/core/auth/biometric_service.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';

/// Account-level settings reached from More → Settings. Today: just the
/// biometric-unlock toggle. Future settings (notifications, language,
/// theme) join here as additional rows.
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
    context.canPop() ? context.pop() : context.go(Routes.more);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
          tooltip: 'Back',
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                children: <Widget>[
                  const _SectionLabel(label: 'Security'),
                  SizedBox(height: 8.h),
                  _BiometricRow(
                    enabled: _biometricEnabled,
                    available: _biometricAvailable,
                    busy: _busy,
                    onChanged: _toggleBiometric,
                  ),
                ],
              ),
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
                        ? 'Use fingerprint or face to sign in faster.'
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
            Switch.adaptive(
              value: enabled,
              onChanged: disabled ? null : onChanged,
              activeThumbColor: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
