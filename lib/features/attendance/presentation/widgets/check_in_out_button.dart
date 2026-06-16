import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_exceptions.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_today_status.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/check_in_not_allowed_dialog.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/check_out_not_allowed_dialog.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/half_day_checkout_dialog.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/outside_geofence_dialog.dart';
import 'package:sales_sphere_erp/shared/utils/error_messages.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Check-In / Check-Out button, driven by `attendanceTodayStatusProvider`.
///
/// The flow is **server-driven** (mirrors v1): the button just attempts the
/// action and reacts to the backend's structured restriction errors. There's
/// no client-side time-window math — the only client gate is the geofence /
/// location check in [AttendanceController].
///
///   - Not checked in  → "Check In"  → on [CheckInRestrictionException] show
///                        the reason dialog.
///   - Checked in       → "Check Out" → full-day attempt; on a
///                        [CheckOutRestrictionException] with
///                        `canUseHalfDayFallback` offer a half-day checkout.
///   - Checked out      → hidden (slot preserved).
class CheckInOutButton extends ConsumerStatefulWidget {
  const CheckInOutButton({super.key});

  @override
  ConsumerState<CheckInOutButton> createState() => _CheckInOutButtonState();
}

class _CheckInOutButtonState extends ConsumerState<CheckInOutButton> {
  bool _busy = false;

  // ── actions ──────────────────────────────────────────────────────────────

  Future<void> _checkIn(AttendanceTodayStatus status) async {
    setState(() => _busy = true);
    try {
      await ref.read(attendanceControllerProvider.notifier).checkIn();
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Checked in successfully.');
    } on CheckInRestrictionException catch (e) {
      if (!mounted) return;
      unawaited(
        CheckInNotAllowedDialog.show(
          context,
          title: _checkInTitle(e.reason),
          message: _checkInMessage(e),
        ),
      );
    } on CheckOutRestrictionException catch (e) {
      // Defensive: shouldn't happen on a check-in, but surface its message.
      if (!mounted) return;
      SnackbarUtils.showError(context, e.message ?? 'Check-in is not allowed.');
    } on AttendanceConflictException catch (e) {
      if (!mounted) return;
      ref.invalidate(attendanceTodayStatusProvider);
      SnackbarUtils.showInfo(context, e.message);
    } on OutsideGeofenceException catch (e) {
      if (!mounted) return;
      _showGeofenceBlocked(e, status.geofence.address);
    } on LocationUnavailableException catch (e) {
      if (!mounted) return;
      _showLocationRequired(e);
    } on Exception catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(context, userMessageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOut({
    required bool isHalfDay,
    required AttendanceTodayStatus status,
  }) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(attendanceControllerProvider.notifier)
          .checkOut(isHalfDay: isHalfDay);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Checked out successfully.');
    } on CheckOutRestrictionException catch (e) {
      if (!mounted) return;
      await _handleCheckoutRestriction(e, status, attemptedHalfDay: isHalfDay);
    } on AttendanceConflictException catch (e) {
      if (!mounted) return;
      ref.invalidate(attendanceTodayStatusProvider);
      SnackbarUtils.showInfo(context, e.message);
    } on OutsideGeofenceException catch (e) {
      if (!mounted) return;
      _showGeofenceBlocked(e, status.geofence.address);
    } on LocationUnavailableException catch (e) {
      if (!mounted) return;
      _showLocationRequired(e);
    } on Exception catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(context, userMessageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Half-day fallback (mirrors v1): when a full-day checkout is refused but
  /// the server says half-day is available, offer it and re-submit. If there's
  /// no fallback (or a half-day attempt itself was refused), show the timing
  /// dialog.
  Future<void> _handleCheckoutRestriction(
    CheckOutRestrictionException e,
    AttendanceTodayStatus status, {
    required bool attemptedHalfDay,
  }) async {
    if (!attemptedHalfDay && e.canUseHalfDayFallback) {
      final confirmed = await HalfDayCheckoutDialog.show(
        context,
        fullDayAvailableFrom: e.fullDayAllowedFrom ?? '--:--',
      );
      if ((confirmed ?? false) && mounted) {
        await _checkOut(isHalfDay: true, status: status);
      }
      return;
    }
    unawaited(
      CheckoutNotAllowedDialog.show(
        context,
        scheduledCheckOut: e.scheduledCheckOut ?? '--:--',
        fullDayAllowedFrom: e.fullDayAllowedFrom ?? '--:--',
        halfDayAvailableAt: e.halfDayAllowedFrom ?? '--:--',
      ),
    );
  }

  void _showGeofenceBlocked(OutsideGeofenceException e, String? officeAddress) {
    unawaited(
      OutsideGeofenceDialog.show(
        context,
        distanceMeters: e.distanceMeters,
        radiusMeters: e.radiusMeters,
        officeAddress: officeAddress,
      ),
    );
  }

  void _showLocationRequired(LocationUnavailableException e) {
    SnackbarUtils.showErrorWithAction(
      context,
      e.message,
      actionLabel: 'Settings',
      onAction: () => ref.read(locationServiceProvider).openAppSettings(),
    );
  }

  // ── copy builders ──────────────────────────────────────────────────────

  String _checkInTitle(CheckInDeniedReason reason) {
    switch (reason) {
      case CheckInDeniedReason.weeklyOff:
        return 'Weekly Off';
      case CheckInDeniedReason.onLeave:
        return 'On Leave';
      case CheckInDeniedReason.tooEarly:
      case CheckInDeniedReason.windowClosed:
      case CheckInDeniedReason.unknown:
        return 'Check-In Not Allowed';
    }
  }

  String _checkInMessage(CheckInRestrictionException e) {
    switch (e.reason) {
      case CheckInDeniedReason.tooEarly:
        return 'Check-in opens at ${e.allowedFrom ?? '--:--'}. Please try again then.';
      case CheckInDeniedReason.windowClosed:
        return 'The check-in window has closed. It was open from '
            '${e.allowedFrom ?? '--:--'} to ${e.allowedUntil ?? '--:--'}.';
      case CheckInDeniedReason.weeklyOff:
        final day = (e.weeklyOffDay != null && e.weeklyOffDay!.isNotEmpty)
            ? _titleCase(e.weeklyOffDay!)
            : 'Today';
        return "$day is the organisation's weekly off — you can't check in today.";
      case CheckInDeniedReason.onLeave:
        return "You're marked on leave today, so check-in isn't available.";
      case CheckInDeniedReason.unknown:
        return e.message ?? 'Check-in is not allowed right now.';
    }
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ref.watch(attendanceTodayStatusProvider).when(
          loading: _loadingButton,
          error: (_, __) => _retryButton(),
          data: _buildForStatus,
        );
  }

  Widget _buildForStatus(AttendanceTodayStatus status) {
    final record = status.record;
    final hasCheckIn = record?.hasCheckIn ?? false;
    final hasCheckOut = record?.hasCheckOut ?? false;

    if (hasCheckOut) {
      // Hidden once fully checked out; keep the slot so the calendar doesn't
      // jump up.
      return const Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: PrimaryButton(
          label: 'Check Out',
          leadingIcon: Icons.logout_rounded,
          size: ButtonSize.large,
        ),
      );
    }

    if (!hasCheckIn) {
      return PrimaryButton(
        label: 'Check In',
        leadingIcon: Icons.login_rounded,
        isLoading: _busy,
        size: ButtonSize.large,
        onPressed: () => _checkIn(status),
      );
    }

    return PrimaryButton(
      label: 'Check Out',
      leadingIcon: Icons.logout_rounded,
      isLoading: _busy,
      size: ButtonSize.large,
      onPressed: () => _checkOut(isHalfDay: false, status: status),
    );
  }

  Widget _loadingButton() => const PrimaryButton(
        label: 'Check In',
        leadingIcon: Icons.login_rounded,
        size: ButtonSize.large,
        isLoading: true,
      );

  Widget _retryButton() => PrimaryButton(
        label: 'Retry',
        leadingIcon: Icons.refresh_rounded,
        size: ButtonSize.large,
        onPressed: () => ref.invalidate(attendanceTodayStatusProvider),
      );
}
