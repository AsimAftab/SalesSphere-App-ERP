import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// How a payment was collected from a party. UI-facing — decoupled from
/// any wire shape so a future backend rename doesn't ripple into
/// widgets. Each mode carries its own display label, icon and accent
/// colour so the picker, the list-card chip and the filter chips all
/// read consistently.
///
/// Some modes need extra detail before a collection is complete:
/// cheque / bank transfer record which `bankName` the money moved
/// through, and a cheque additionally records its number, date and
/// clearing `status`. See [requiresBank] / [requiresChequeDetails].
enum PaymentMode { cash, cheque, bankTransfer, qrPay }

/// Presentation + behaviour metadata for a [PaymentMode]. Kept beside
/// the enum so the label/icon/accent and the "which fields does this
/// mode need" rules live in one place.
extension PaymentModeX on PaymentMode {
  String get label => switch (this) {
    PaymentMode.cash => 'Cash',
    PaymentMode.cheque => 'Cheque',
    PaymentMode.bankTransfer => 'Bank Transfer',
    PaymentMode.qrPay => 'QR Pay',
  };

  IconData get icon => switch (this) {
    PaymentMode.cash => Icons.payments_outlined,
    PaymentMode.cheque => Icons.receipt_long_outlined,
    PaymentMode.bankTransfer => Icons.account_balance_outlined,
    PaymentMode.qrPay => Icons.qr_code_2_rounded,
  };

  Color get accent => switch (this) {
    PaymentMode.cash => AppColors.green500,
    PaymentMode.cheque => AppColors.warning,
    PaymentMode.bankTransfer => AppColors.secondary,
    PaymentMode.qrPay => AppColors.purple500,
  };

  /// Cheque and bank transfer move money through a named bank, so the
  /// form surfaces the bank-name field for them.
  bool get requiresBank =>
      this == PaymentMode.cheque || this == PaymentMode.bankTransfer;

  /// Only a cheque carries a number / date / clearing status.
  bool get requiresChequeDetails => this == PaymentMode.cheque;
}

/// Resolves a [PaymentMode] from its display [label]. Returns `null`
/// when nothing matches — used by the string-based option picker to map
/// the picked label back to the enum.
PaymentMode? paymentModeFromLabel(String? label) {
  if (label == null) return null;
  for (final m in PaymentMode.values) {
    if (m.label == label) return m;
  }
  return null;
}
