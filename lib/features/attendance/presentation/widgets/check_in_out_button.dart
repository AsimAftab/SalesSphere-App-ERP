import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/attendance/domain/work_schedule.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/check_in_not_allowed_dialog.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/check_out_not_allowed_dialog.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Check-In / Check-Out button with time-window enforcement.
///
/// State machine (check-in, not yet checked in):
///   - Weekly off            → button enabled; tap shows [CheckInNotAllowedDialog]
///   - Before allowed window → button **disabled** + hint text below
///   - After allowed window  → button enabled; tap shows [CheckInNotAllowedDialog]
///   - Inside window         → button enabled; tap performs check-in
///
/// State machine (check-out, checked in but not yet checked out):
///   - Before full-day AND outside half-day window
///                           → button enabled; tap shows [CheckoutNotAllowedDialog]
///   - Inside half-day or full-day window
///                           → button enabled; tap performs check-out
///
/// Once both check-in and check-out are recorded the button is hidden
/// (space preserved via [Visibility.maintainSize]).
class CheckInOutButton extends ConsumerStatefulWidget {
  const CheckInOutButton({super.key});

  @override
  ConsumerState<CheckInOutButton> createState() => _CheckInOutButtonState();
}

class _CheckInOutButtonState extends ConsumerState<CheckInOutButton> {
  bool _busy = false;

  // ── actions ──────────────────────────────────────────────────────────────

  Future<void> _onPressed({required bool isCheckIn}) async {
    setState(() => _busy = true);
    try {
      final controller = ref.read(attendanceControllerProvider.notifier);
      if (isCheckIn) {
        await controller.checkIn();
        if (!mounted) return;
        SnackbarUtils.showSuccess(context, 'Checked in successfully.');
      } else {
        await controller.checkOut();
        if (!mounted) return;
        SnackbarUtils.showSuccess(context, 'Checked out successfully.');
      }
    } on Exception catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      fullDayAllowedFrom: schedule.formatDt(schedule.fullDayCheckOutAllowedFrom(date)),
      halfDayAvailableAt: schedule.formatDt(schedule.halfDayCheckOutAllowedFrom(date)),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayAttendanceProvider);
    final schedule = ref.watch(workScheduleProvider);
    final todayRecord = todayAsync.value;
    final hasCheckIn = todayRecord?.hasCheckIn ?? false;
    final hasCheckOut = todayRecord?.hasCheckOut ?? false;
    final now = DateTime.now();

    // ── hidden after full checkout ──────────────────────────────────────────
    // Keep the slot occupied so the calendar doesn't jump up.
    if (hasCheckOut) {
      return Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: PrimaryButton(
          label: 'Check Out',
          leadingIcon: Icons.logout_rounded,
          size: ButtonSize.large,
          onPressed: null,
        ),
      );
    }

    // ── CHECK-IN ────────────────────────────────────────────────────────────
    if (!hasCheckIn) {
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

      final windowStatus = schedule.checkInStatus(now);
      switch (windowStatus) {
        case CheckInWindowStatus.tooEarly:
          // Disabled button + "available at X" hint (mirrors Screenshot 3).
          final date = DateTime(now.year, now.month, now.day);
          final openAt = schedule.checkInAllowedFrom(date);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              PrimaryButton(
                label: 'Check In',
                leadingIcon: Icons.login_rounded,
                size: ButtonSize.large,
                isDisabled: true,
                onPressed: null,
              ),
              SizedBox(height: 8.h),
              Text(
                'Check-in becomes available at ${DateFormat('h:mm a').format(openAt)}',
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
          // Window closed: button tappable but shows info dialog.
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
            onPressed: () => _onPressed(isCheckIn: true),
          );
      }
    }

    // ── CHECK-OUT ───────────────────────────────────────────────────────────
    final checkOutStatus = schedule.checkOutStatus(now);
    if (checkOutStatus == CheckOutWindowStatus.tooEarly) {
      // Neither full-day nor half-day window is open yet — show info dialog.
      return PrimaryButton(
        label: 'Check Out',
        leadingIcon: Icons.logout_rounded,
        isLoading: _busy,
        size: ButtonSize.large,
        onPressed: () => _showCheckoutNotAllowed(schedule, now),
      );
    }

    // Full-day or half-day window is open — proceed normally.
    return PrimaryButton(
      label: 'Check Out',
      leadingIcon: Icons.logout_rounded,
      isLoading: _busy,
      size: ButtonSize.large,
      onPressed: () => _onPressed(isCheckIn: false),
    );
  }
}
