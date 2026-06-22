import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Clearing state of a collected cheque. Only relevant when the
/// collection's payment mode is `cheque`. UI-facing — carries its own
/// label / icon / accent so the picker and any future status chip read
/// as the same family as the rest of the app.
enum ChequeStatus { pending, deposited, cleared, bounced }

/// Presentation metadata for a [ChequeStatus]. Kept beside the enum so
/// the label/icon/accent live in one place.
extension ChequeStatusX on ChequeStatus {
  String get label => switch (this) {
    ChequeStatus.pending => 'Pending',
    ChequeStatus.deposited => 'Deposited',
    ChequeStatus.cleared => 'Cleared',
    ChequeStatus.bounced => 'Bounced',
  };

  IconData get icon => switch (this) {
    ChequeStatus.pending => Icons.hourglass_empty_rounded,
    ChequeStatus.deposited => Icons.account_balance_wallet_outlined,
    ChequeStatus.cleared => Icons.check_circle_outline_rounded,
    ChequeStatus.bounced => Icons.cancel_outlined,
  };

  Color get color => switch (this) {
    ChequeStatus.pending => AppColors.warning,
    ChequeStatus.deposited => AppColors.secondary,
    ChequeStatus.cleared => AppColors.green500,
    ChequeStatus.bounced => AppColors.error,
  };
}

/// Resolves a [ChequeStatus] from its display [label]. Returns `null`
/// when nothing matches — used by the string-based option picker to map
/// the picked label back to the enum.
ChequeStatus? chequeStatusFromLabel(String? label) {
  if (label == null) return null;
  for (final s in ChequeStatus.values) {
    if (s.label == label) return s;
  }
  return null;
}
