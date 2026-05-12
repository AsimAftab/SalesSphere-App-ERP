import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';

/// Flips label between "Check In" / "Check Out" / "Checked Out" based
/// on `todayAttendanceProvider`. Disabled in the third state so the
/// user can't double-check-out.
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

    if (hasCheckOut) {
      return PrimaryButton(
        label: 'Checked Out',
        leadingIcon: Icons.check_circle_outline_rounded,
        isDisabled: true,
        size: ButtonSize.large,
        onPressed: () {},
      );
    }

    final isCheckIn = !hasCheckIn;
    return PrimaryButton(
      label: isCheckIn ? 'Check In' : 'Check Out',
      leadingIcon: isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
      isLoading: _busy,
      size: ButtonSize.large,
      onPressed: () => _onPressed(isCheckIn: isCheckIn),
    );
  }
}
