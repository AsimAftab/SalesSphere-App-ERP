import 'package:flutter/material.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice.dart';

/// Accent colour per invoice status — shared by the history badge and the
/// detail page so they read as the same component family.
Color invoiceStatusColor(InvoiceStatus status) => switch (status) {
  InvoiceStatus.pending => AppColors.warning,
  InvoiceStatus.inProgress => AppColors.secondary,
  InvoiceStatus.inTransit => AppColors.purple500,
  InvoiceStatus.completed => AppColors.green500,
  InvoiceStatus.rejected => AppColors.error,
};

IconData invoiceStatusIcon(InvoiceStatus status) => switch (status) {
  InvoiceStatus.pending => Icons.hourglass_empty_rounded,
  InvoiceStatus.inProgress => Icons.autorenew_rounded,
  InvoiceStatus.inTransit => Icons.local_shipping_outlined,
  InvoiceStatus.completed => Icons.check_circle_outline_rounded,
  InvoiceStatus.rejected => Icons.cancel_outlined,
};

/// Badge label for a saved record. Estimates always read "Estimate"
/// (their non-binding nature is what matters, not a fulfilment status);
/// invoices show their fulfilment status.
String invoiceBadgeLabel(Invoice invoice) =>
    invoice.kind == InvoiceKind.estimate
    ? 'Estimate'
    : invoiceStatusLabel(invoice.status);

/// Accent colour for [invoiceBadgeLabel]. Estimates use the orange
/// [AppColors.textOrange] — a warm accent that clearly sets quotations
/// apart from the blue invoices. It is also the estimate's "View Details"
/// button colour, so the badge matches its button. Invoices keep their
/// per-status colour.
Color invoiceBadgeColor(Invoice invoice) => invoice.kind == InvoiceKind.estimate
    ? AppColors.textOrange
    : invoiceStatusColor(invoice.status);

/// Filled-button accent per document kind: invoices use the brand blue
/// [AppColors.secondary], estimates the orange [AppColors.textOrange].
/// Drives the "View Details" button so the two kinds are tellable apart at
/// a glance. Both take white foreground text.
Color invoiceKindColor(InvoiceKind kind) => kind == InvoiceKind.estimate
    ? AppColors.textOrange
    : AppColors.secondary;
