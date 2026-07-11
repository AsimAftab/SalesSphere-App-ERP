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
/// ```
/// pending ──► deposited ──► cleared   (terminal)
///    │            │
///    └────────────┴───────► bounced   (terminal)
/// ```
///
/// `pending → cleared` directly is allowed — a cheque can be banked and clear
/// without a separate deposit step ever being recorded. Nothing moves backwards
/// and nothing leaves a terminal state; the server refuses with a 409, so the
/// UI simply doesn't offer the move.
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

  /// What actually happens when a cheque on a **plain Collection** moves here.
  ///
  /// A plain Collection has no ledger: these transitions write no voucher and
  /// move no money. They record what the cheque did in the real world, and
  /// nothing more. So the copy says what *happened*, not what didn't — telling
  /// a rep "no accounting entry was created" is both confusing and beside the
  /// point.
  ///
  /// The bounce copy names the targets consequence on purpose. A rep watching
  /// their collection number drop deserves to know why it dropped.
  String get confirmationCopy => switch (this) {
    ChequeStatus.pending => 'The cheque goes back to pending.',
    ChequeStatus.deposited =>
      'The cheque has been handed in at the bank. The money has not arrived '
          'yet — it is not yours until the bank clears it.',
    ChequeStatus.cleared =>
      'The bank honoured the cheque and the money is now in your account. '
          'This closes the cheque — the customer has paid.',
    ChequeStatus.bounced =>
      'The bank refused the cheque, so the money never arrived. The customer '
          'still owes you, and this receipt stops counting towards your '
          'collection targets. This is final — record a new collection if they '
          'pay again.',
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
