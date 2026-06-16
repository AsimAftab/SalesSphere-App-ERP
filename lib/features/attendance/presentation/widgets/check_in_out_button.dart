import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_today_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/work_schedule.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/check_in_not_allowed_dialog.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/check_out_not_allowed_dialog.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/half_day_checkout_dialog.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/outside_geofence_dialog.dart';
import 'package:sales_sphere_erp/shared/utils/error_messages.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Check-In / Check-Out button driven by `attendanceTodayStatusProvider`
/// (today's record + org schedule + geofence config).
///
/// Check-in state machine (not yet checked in):
///   - Weekly off            → button enabled; tap shows [CheckInNotAllowedDialog]
///   - Before allowed window → button **disabled** + hint text below
///   - After allowed window  → button enabled; tap shows [CheckInNotAllowedDialog]
///   - Inside window         → button enabled; tap performs check-in
///
/// Check-out (checked in, not yet checked out) — reactive, mirrors v1:
///   - Before any window     → tap shows [CheckoutNotAllowedDialog]
///   - Half-day window only  → tap shows [HalfDayCheckoutDialog] fallback
///   - Full-day window open  → tap checks out full-day directly (no prompt)
///
/// Both actions capture location + enforce the geofence in the controller;
/// the button surfaces [OutsideGeofenceException] / [LocationUnavailableException]
/// and any server gating message. Once fully checked out the button is hidden
/// (space preserved via [Visibility.maintainSize]).
class CheckInOutButton extends ConsumerStatefulWidget {
  const CheckInOutButton({super.key});

  @override
  ConsumerState<CheckInOutButton> createState() => _CheckInOutButtonState();
}

class _CheckInOutButtonState extends ConsumerState<CheckInOutButton> {
  bool _busy = false;

  // ── actions ──────────────────────────────────────────────────────────────

  Future<void> _onCheckIn(AttendanceTodayStatus status) async {
    setState(() => _busy = true);
    try {
      await ref.read(attendanceControllerProvider.notifier).checkIn();
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Checked in successfully.');
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

  Future<void> _onCheckOut({
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

  /// Half-day fallback (mirrors v1): only reached when the full-day window
  /// isn't open yet but the half-day window is. Confirms before submitting.
  Future<void> _promptHalfDayCheckout(
    AttendanceTodayStatus status,
    WorkSchedule schedule,
    DateTime now,
  ) async {
    final date = DateTime(now.year, now.month, now.day);
    final confirmed = await HalfDayCheckoutDialog.show(
      context,
      fullDayAvailableFrom:
          schedule.formatDt(schedule.fullDayCheckOutAllowedFrom(date)),
    );
    if (confirmed != true || !mounted) return;
    await _onCheckOut(isHalfDay: true, status: status);
  }

  void _showCheckInNotAllowed(
    WorkSchedule schedule,
    CheckInDeniedReason reason,
    DateTime now,
  ) {
    final date = DateTime(now.year, now.month, now.day);
    CheckInNotAllowedDialog.show(
      context,
      reason: reason,
      weekdayName: WorkSchedule.weekdayName(now.weekday),
      allowedFrom: schedule.formatDt(schedule.checkInAllowedFrom(date)),
      allowedUntil: schedule.formatDt(schedule.checkInAllowedUntil(date)),
    );
  }

  void _showCheckoutNotAllowed(WorkSchedule schedule, DateTime now) {
    final date = DateTime(now.year, now.month, now.day);
    CheckoutNotAllowedDialog.show(
      context,
      scheduledCheckOut: schedule.formatTod(schedule.scheduledCheckOut),
      fullDayAllowedFrom:
          schedule.formatDt(schedule.fullDayCheckOutAllowedFrom(date)),
      halfDayAvailableAt:
          schedule.formatDt(schedule.halfDayCheckOutAllowedFrom(date)),
    );
  }

  void _showGeofenceBlocked(OutsideGeofenceException e, String? officeAddress) {
    OutsideGeofenceDialog.show(
      context,
      distanceMeters: e.distanceMeters,
      radiusMeters: e.radiusMeters,
      officeAddress: officeAddress,
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
    final schedule = status.schedule;
    final record = status.record;
    final hasCheckIn = record?.hasCheckIn ?? false;
    final hasCheckOut = record?.hasCheckOut ?? false;
    final now = DateTime.now();

    // ── hidden after full checkout ──────────────────────────────────────────
    // Keep the slot occupied so the calendar doesn't jump up.
    if (hasCheckOut) {
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
      return _buildCheckIn(status, schedule, now);
    }
    return _buildCheckOut(status, schedule, now);
  }

  Widget _buildCheckIn(
    AttendanceTodayStatus status,
    WorkSchedule schedule,
    DateTime now,
  ) {
    // Weekly-off: button tappable but shows info dialog.
    if (schedule.isWeeklyOff(now)) {
      return PrimaryButton(
        label: 'Check In',
        leadingIcon: Icons.login_rounded,
        isLoading: _busy,
        size: ButtonSize.large,
        onPressed: () =>
            _showCheckInNotAllowed(schedule, CheckInDeniedReason.weeklyOff, now),
      );
    }

    switch (schedule.checkInStatus(now)) {
      case CheckInWindowStatus.tooEarly:
        final date = DateTime(now.year, now.month, now.day);
        final openAt = schedule.checkInAllowedFrom(date);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const PrimaryButton(
              label: 'Check In',
              leadingIcon: Icons.login_rounded,
              size: ButtonSize.large,
              isDisabled: true,
            ),
            SizedBox(height: 8.h),
            Text(
              'Check-in becomes available at '
              '${DateFormat('h:mm a').format(openAt)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                height: 1.4,
              ),
            ),
          ],
        );

      case CheckInWindowStatus.tooLate:
        return PrimaryButton(
          label: 'Check In',
          leadingIcon: Icons.login_rounded,
          isLoading: _busy,
          size: ButtonSize.large,
          onPressed: () =>
              _showCheckInNotAllowed(schedule, CheckInDeniedReason.tooLate, now),
        );

      case CheckInWindowStatus.allowed:
        return PrimaryButton(
          label: 'Check In',
          leadingIcon: Icons.login_rounded,
          isLoading: _busy,
          size: ButtonSize.large,
          onPressed: () => _onCheckIn(status),
        );
    }
  }

  Widget _buildCheckOut(
    AttendanceTodayStatus status,
    WorkSchedule schedule,
    DateTime now,
  ) {
    // Reactive checkout (mirrors v1): full-day goes through directly; half-day
    // is only offered as a fallback when full-day isn't open yet.
    final VoidCallback onPressed;
    switch (schedule.checkOutStatus(now)) {
      case CheckOutWindowStatus.tooEarly:
        onPressed = () => _showCheckoutNotAllowed(schedule, now);
      case CheckOutWindowStatus.halfDayAllowed:
        onPressed = () => _promptHalfDayCheckout(status, schedule, now);
      case CheckOutWindowStatus.fullDayAllowed:
        onPressed = () => _onCheckOut(isHalfDay: false, status: status);
    }

    return PrimaryButton(
      label: 'Check Out',
      leadingIcon: Icons.logout_rounded,
      isLoading: _busy,
      size: ButtonSize.large,
      onPressed: onPressed,
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
