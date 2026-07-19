import 'package:flutter/foundation.dart';

import 'package:sales_sphere_erp/features/collection_plus/domain/collection_invoice.dart';

/// An outstanding invoice for a party — what the collection form's
/// invoice list and allocation preview work off.
///
/// [paid] is the sum of every collection allocation already booked
/// against [invoice]; [outstanding] is the remaining balance
/// (`invoice.amount - paid`), clamped at zero so an over-allocated seed
/// row can't show a negative due. [lastPaidOn] is the most recent
/// collection date among those allocations (`null` when nothing has been
/// collected yet) — shown on the picker card so the user sees when the
/// last instalment came in.
@immutable
class InvoiceDue {
  const InvoiceDue({
    required this.invoice,
    required this.paid,
    required this.outstanding,
    this.lastPaidOn,
    this.priorPayments = const <PriorPayment>[],
  });

  final CollectionPlusInvoice invoice;
  final double paid;
  final double outstanding;
  final DateTime? lastPaidOn;

  /// The individual allocations that sum to [paid], oldest-first, so the UI can
  /// list each prior payment with its own received date instead of a single
  /// grouped "Paid" figure. Empty for older receipts the server recorded before
  /// it started emitting the breakdown — callers fall back to [paid]/[lastPaidOn].
  final List<PriorPayment> priorPayments;
}

/// One prior payment booked against an invoice: an [amount] received on a
/// [receivedDate]. History only — there is no collection number to link back to.
@immutable
class PriorPayment {
  const PriorPayment({required this.amount, required this.receivedDate});

  final double amount;
  final DateTime receivedDate;
}
