import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Flips label between "Check In" and "Check Out" based on
/// `todayAttendanceProvider`. Collapses to `SizedBox.shrink()` once
/// the day's check-out is recorded — at that point the user has
/// nothing left to do and the "Today's Status" card carries the
/// timestamps.
class CheckInOutButton extends ConsumerStatefulWidget {
  const CheckInOutButton({super.key});

  @override
  ConsumerState<CheckInOutButton> createState() => _CheckInOutButtonState();
}

class _CheckInOutButtonState extends ConsumerState<CheckInOutButton> {
  bool _busy = false;

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

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayAttendanceProvider);
    final today = todayAsync.value;
    final hasCheckIn = today?.hasCheckIn ?? false;
    final hasCheckOut = today?.hasCheckOut ?? false;

    final isCheckIn = !hasCheckIn;
    final button = PrimaryButton(
      label: isCheckIn ? 'Check In' : 'Check Out',
      leadingIcon: isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
      isLoading: _busy,
      size: ButtonSize.large,
      onPressed: () => _onPressed(isCheckIn: isCheckIn),
    );

    // Once the day is closed out the button has nothing left to do —
    // hide it but keep the slot occupied so the surrounding spacers
    // don't collapse and the calendar doesn't jump up. `maintainSize`
    // reserves the height; `maintainState` skips rebuilds; the inert
    // hit-test stops a stray tap from firing on an invisible widget.
    if (hasCheckOut) {
      return Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: button,
      );
    }

    return button;
  }
}
