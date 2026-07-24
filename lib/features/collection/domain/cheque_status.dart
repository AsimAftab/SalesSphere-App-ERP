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

/// The cheque clearing lifecycle, mirrored from the server:
///
/// `	ext`
/// pending ──► deposited ──► cleared   (terminal)
///    │            │
///    └────────────┴───────► bounced   (terminal)
/// `	ext`
///
/// `pending → cleared` directly is allowed. Nothing moves backwards and nothing
/// leaves a terminal state; the server refuses with a 409, so the UI doesn't
/// offer the move.
extension ChequeStatusTransitions on ChequeStatus {
  List<ChequeStatus> get nextStates => switch (this) {
    ChequeStatus.pending => const <ChequeStatus>[
      ChequeStatus.deposited,
      ChequeStatus.cleared,
      ChequeStatus.bounced,
    ],
    ChequeStatus.deposited => const <ChequeStatus>[
      ChequeStatus.cleared,
      ChequeStatus.bounced,
    ],
    ChequeStatus.cleared => const <ChequeStatus>[],
    ChequeStatus.bounced => const <ChequeStatus>[],
  };

  bool get isTerminal => nextStates.isEmpty;

  /// What actually happens when a cheque on a receipt moves here.
  ///
  /// Receipts are ledger-backed, so on a posted one these transitions do real
  /// PDC accounting — and the copy names the entries, because an accountant
  /// reading it needs to know what was written.
  String get confirmationCopy => switch (this) {
    ChequeStatus.pending => 'The cheque goes back to pending.',
    ChequeStatus.deposited =>
      'The cheque has been handed in at the bank. The money has not arrived '
          'yet — it stays in Cheque-in-Hand until the bank clears it.',
    ChequeStatus.cleared =>
      'The bank honoured the cheque. A contra entry moves the money from '
          'Cheque-in-Hand into the bank account. This closes the cheque.',
    ChequeStatus.bounced =>
      'The bank refused the cheque. A reversal is written: the receipt is '
          'cancelled, every invoice it settled goes back to outstanding, and it '
          'stops counting towards collection targets. This is final — record a '
          'new collection if the customer pays again.',
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


