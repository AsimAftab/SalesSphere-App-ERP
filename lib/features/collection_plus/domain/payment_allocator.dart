import 'package:sales_sphere_erp/features/collection_plus/domain/collection_allocation.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/invoice_due.dart';

/// Pure FIFO payment allocation.
///
/// A payment collected from a party is applied to that party's
/// outstanding invoices oldest-first: each invoice is filled to its
/// outstanding balance before the remainder spills to the next. The same
/// function drives the live allocation preview on the form and the stored
/// breakdown on submit, so the two can never disagree.
abstract final class PaymentAllocator {
  /// Splits [amount] across [dues] — which **must already be ordered
  /// oldest-first** — filling each invoice's outstanding before moving on.
  ///
  /// Stops once the amount is exhausted; any remainder beyond the total
  /// outstanding is dropped (callers block overpayment via
  /// [totalOutstanding] before recording, so a well-formed call never
  /// leaves a remainder).
  static List<CollectionPlusAllocation> allocate(
    double amount,
    List<InvoiceDue> dues,
  ) {
    var remaining = amount;
    final result = <CollectionPlusAllocation>[];
    for (final due in dues) {
      if (remaining <= 0) break;
      final take = remaining < due.outstanding ? remaining : due.outstanding;
      if (take <= 0) continue;
      result.add(
        CollectionPlusAllocation(
          invoiceId: due.invoice.id,
          invoiceNumber: due.invoice.number,
          amount: take,
        ),
      );
      remaining -= take;
    }
    return result;
  }

  /// Sum of outstanding balances across [dues] — the most a single
  /// collection can settle, used as the overpayment cap.
  static double totalOutstanding(List<InvoiceDue> dues) =>
      dues.fold<double>(0, (sum, due) => sum + due.outstanding);
}
