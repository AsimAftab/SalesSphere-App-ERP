import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// One offerable cheque transition, flattened out of whichever module's
/// `ChequeStatus` enum the caller owns.
///
/// Generic over the enum rather than naming it, so any feature with a cheque
/// lifecycle can drive this widget. It takes the already-resolved label / icon
/// / colour / copy, which lets each caller supply wording honest to what its
/// own transitions actually do.
@immutable
class ChequeTransition<T> {
  const ChequeTransition({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.confirmationCopy,
  });

  final T value;
  final String label;
  final IconData icon;
  final Color color;

  /// What this transition actually does, in the user's terms. Shown in the
  /// confirmation dialog.
  final String confirmationCopy;
}

/// Ask the user to pick a cheque transition, then confirm it.
///
/// Returns the chosen value, or `null` if they backed out at either step.
///
/// Two steps on purpose. A cheque bounce is irreversible and, on Collection
/// Plus, reverses a posted voucher and restores every invoice it settled — that
/// is not something to fire from a single mis-tap. The confirmation always
/// states what *will happen*, never a bare "Are you sure?".
///
/// Only legal transitions should be passed in: the server enforces the state
/// machine and 409s anything else, so offering an illegal move only sets the
/// user up to be refused.
Future<T?> showChequeStatusSheet<T>({
  required BuildContext context,
  required String currentLabel,
  required List<ChequeTransition<T>> transitions,
}) async {
  final picked = await showModalBottomSheet<ChequeTransition<T>>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 4.h),
            child: Text(
              'Update cheque status',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
            child: Text(
              'Currently $currentLabel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.sp,
              ),
            ),
          ),
          for (final t in transitions)
            ListTile(
              leading: Icon(t.icon, color: t.color, size: 22.sp),
              title: Text(
                t.label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop(t),
            ),
          SizedBox(height: 12.h),
        ],
      ),
    ),
  );

  if (picked == null || !context.mounted) return null;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        'Mark as ${picked.label}?',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 17.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        picked.confirmationCopy,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14.sp,
          height: 1.45,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: picked.color),
          child: Text('Mark as ${picked.label}'),
        ),
      ],
    ),
  );

  return confirmed ?? false ? picked.value : null;
}
