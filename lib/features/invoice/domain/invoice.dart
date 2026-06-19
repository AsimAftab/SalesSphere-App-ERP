import 'package:flutter/foundation.dart';

import 'package:sales_sphere_erp/features/invoice/domain/invoice_line_item.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_party.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_totals.dart';
import 'package:sales_sphere_erp/features/invoice/domain/tax_option.dart';

/// Whether a saved record is a committed invoice or a non-binding
/// estimate/quotation. Drives the two History tabs and the document
/// number prefix (`INV-` / `EST-`).
enum InvoiceKind { invoice, estimate }

String invoiceKindLabel(InvoiceKind kind) =>
    kind == InvoiceKind.invoice ? 'Invoice' : 'Estimate';

/// Fulfilment state of a saved invoice / estimate. New records start
/// [pending]; the rest model the delivery workflow. Drives the status
/// badge on the history cards and the detail page.
enum InvoiceStatus { pending, inProgress, inTransit, completed, rejected }

String invoiceStatusLabel(InvoiceStatus status) => switch (status) {
      InvoiceStatus.pending => 'Pending',
      InvoiceStatus.inProgress => 'In Progress',
      InvoiceStatus.inTransit => 'In Transit',
      InvoiceStatus.completed => 'Completed',
      InvoiceStatus.rejected => 'Rejected',
    };

/// A saved invoice or estimate. Built from an `InvoiceDraftData`
/// snapshot at create time and stored in the in-memory history list.
/// Reuses [InvoiceTotals] so history rows show the same grand total the
/// builder did.
@immutable
class Invoice with InvoiceTotals {
  const Invoice({
    required this.id,
    required this.number,
    required this.kind,
    required this.status,
    required this.items,
    required this.overallDiscountPercent,
    required this.tax,
    required this.createdAt,
    this.party,
    this.deliveryDate,
  });

  final String id;

  /// Human-facing document number, e.g. `INV-1007` / `EST-1003`.
  final String number;
  final InvoiceKind kind;
  final InvoiceStatus status;
  final InvoiceParty? party;
  final DateTime? deliveryDate;
  @override
  final List<InvoiceLineItem> items;
  @override
  final double overallDiscountPercent;
  @override
  final TaxOption tax;
  final DateTime createdAt;
}
