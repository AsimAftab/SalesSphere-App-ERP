import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Where a collection sits in the accounting lifecycle.
///
/// Shared by both modules, because the ledger lifecycle is the backend's and is
/// identical for each.
///
/// **[draft] is not an error, and it is not "pending sync".** Sync state lives
/// separately, on `syncPending` / `syncError`.
///
/// The two modules reach the other states differently:
///
///  * **Collection Plus** posts to the ledger. An accountant posts it from the
///    web, which writes the voucher and drops the customer's outstanding
///    balance; cancelling writes a reversal.
///  * **Plain Collection never posts at all.** The backend ships no
///    `/collections/{id}/post` or `/cancel` route and no `collections:post` /
///    `collections:cancel` permission — it's a CRM record of money received.
///    Its status therefore stays [draft] permanently, and its cheque status is
///    metadata rather than an accounting event. That is the correct resting
///    state and must read as normal, not as unfinished work.
enum CollectionStatus { draft, posted, cancelled }

/// Presentation metadata for a [CollectionStatus]. Kept beside the enum so
/// the badge's label/icon/accent live in one place, matching the house shape
/// used by [PaymentMode] and [ChequeStatus].
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
    // Deliberately neutral, not a warning colour — see the enum doc.
    CollectionStatus.draft => AppColors.secondary,
    CollectionStatus.posted => AppColors.green500,
    CollectionStatus.cancelled => AppColors.error,
  };

  /// The server refuses `PATCH` / `DELETE` on anything but a draft (409).
  /// The edit affordance is hidden accordingly.
  bool get isEditable => this == CollectionStatus.draft;
}
