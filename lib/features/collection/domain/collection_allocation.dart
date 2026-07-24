import 'package:flutter/foundation.dart';

/// One slice of a collection's amount applied to a single invoice.
///
/// A payment collected from a party is split across that party's
/// outstanding invoices oldest-first (FIFO) — each slice records how much
/// of the payment landed on which invoice so the stored receipt can show
/// the breakdown. A payment that fits inside one invoice has a single
/// allocation; one that spills across invoices has several.
///
/// Carries the invoice's [invoiceNumber] denormalised so the list / detail
/// cards can render the breakdown without re-resolving the orders corpus.
@immutable
class CollectionAllocation {
  const CollectionAllocation({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.amount,
  });

  /// Source order/invoice id the payment is credited against.
  final String invoiceId;

  /// Human-facing document number, e.g. `ORD-2026-0006`.
  final String invoiceNumber;

  /// Portion of the collection applied to this invoice, in NPR.
  final double amount;
}
