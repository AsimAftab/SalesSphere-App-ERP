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
  });

  final CollectionPlusInvoice invoice;
  final double paid;
  final double outstanding;
  final DateTime? lastPaidOn;
}
