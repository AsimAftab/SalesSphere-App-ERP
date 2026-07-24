import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Where a receipt sits in the accounting lifecycle.
///
/// Plus-only, by design. A plain Collection has no status at all: it's a pure
/// CRM record that a rep collected money, it never posts to a ledger, and it is
/// always editable. Everything ledger-backed — posting, cancelling, real PDC
/// cheque accounting — lives here.
///
/// A rep's receipt lands [draft]. An accountant posts it from the web, which
/// emits a RECEIPT voucher and drops the customer's outstanding balance;
/// cancelling writes a reversal that restores every settled invoice.
///
/// **This is not sync state.** Whether the row has reached the server at all is
/// tracked separately, on `syncPending` / `syncError`. A [draft] receipt is
/// healthy; a red sync badge is not.
enum CollectionStatus { draft, posted, cancelled }

/// Presentation metadata for a [CollectionStatus]. Kept beside the enum so the
/// badge's label/icon/accent live in one place, matching the house shape used
/// by `PaymentMode` and `ChequeStatus`.
extension CollectionStatusX on CollectionStatus {
  String get label => switch (this) {
    CollectionStatus.draft => 'Draft',
    CollectionStatus.posted => 'Posted',
    CollectionStatus.cancelled => 'Cancelled',
  };

  IconData get icon => switch (this) {
    CollectionStatus.draft => Icons.edit_note_rounded,
    CollectionStatus.posted => Icons.verified_outlined,
    CollectionStatus.cancelled => Icons.block_outlined,
  };

  Color get color => switch (this) {
    // Deliberately neutral, not a warning colour — a draft is a normal resting
    // state, not a problem.
    CollectionStatus.draft => AppColors.secondary,
    CollectionStatus.posted => AppColors.green500,
    CollectionStatus.cancelled => AppColors.error,
  };

  /// The server refuses `PATCH` / `DELETE` on anything but a draft (409) — a
  /// posted receipt has a voucher behind it.
  bool get isEditable => this == CollectionStatus.draft;
}
