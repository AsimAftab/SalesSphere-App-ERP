import 'package:sales_sphere_erp/features/collection/domain/collection_allocation.dart';
import 'package:sales_sphere_erp/features/collection/domain/invoice_due.dart';

/// Pure FIFO payment allocation — **preview only**.
///
/// A payment collected from a party is applied to that party's outstanding
/// invoices oldest-first: each invoice is filled to its outstanding balance
/// before the remainder spills to the next.
///
/// ## The server owns the real split
///
/// This runs on-device purely so the form can show the user where their money
/// is about to go. It is **not** what gets booked. The client sends the
/// selected `invoiceIds` plus an amount; the server re-runs this same
/// algorithm against *live* balances and returns the authoritative
/// allocations.
///
/// That distinction matters offline: two reps can each record a receipt
/// against the same invoice, both having previewed against a balance that was
/// already stale. Whoever syncs second gets a 422 telling them the selected
/// invoices no longer cover the amount. That is correct, and it must surface —
/// never quietly re-allocate to make it fit.
///
/// ## Matching the server bit-for-bit
///
/// Two details are load-bearing, and getting either wrong means the preview
/// shows a split that isn't the one that gets booked:
///
///  * **Integer paisa, never floating-point.** `0.1 + 0.2 != 0.3` in binary
///    floating point, and a receipt is money.
///  * **Sort by `invoiceDate` ascending, ties broken by `invoiceNumber`
///    ascending** — exactly what the server does. Two invoices raised on the
///    same day are common, and without the tie-break the two sides can pick a
///    different one to fill first.
abstract final class PaymentAllocator {
  /// Rupees → paisa. Money crosses the wire as a decimal string and is held in
  /// Dart as a double; rounding at the boundary keeps the arithmetic exact.
  static int toPaisa(double rupees) => (rupees * 100).round();

  static double fromPaisa(int paisa) => paisa / 100;

  /// Split [amount] across [dues], oldest invoice first.
  ///
  /// [dues] is sorted defensively rather than trusted — the server already
  /// returns oldest-first, but a caller that filtered or concatenated the list
  /// could easily have disturbed it, and a silently mis-ordered preview is
  /// worse than a slow one.
  ///
  /// Any remainder beyond the total outstanding is dropped; use [unallocated]
  /// to detect it. A non-zero remainder is **not** an error: the server books
  /// it as an on-account advance and reports it back as `unallocatedAmount`.
  /// The form surfaces it so the rep confirms the overshoot is deliberate.
  static List<CollectionAllocation> allocate(
    double amount,
    List<InvoiceDue> dues,
  ) {
    var remaining = toPaisa(amount);
    final result = <CollectionAllocation>[];
    for (final due in _oldestFirst(dues)) {
      if (remaining <= 0) break;
      final outstanding = toPaisa(due.outstanding);
      if (outstanding <= 0) continue;
      final take = remaining < outstanding ? remaining : outstanding;
      result.add(
        CollectionAllocation(
          invoiceId: due.invoice.id,
          invoiceNumber: due.invoice.number,
          amount: fromPaisa(take),
        ),
      );
      remaining -= take;
    }
    return result;
  }

  /// The part of [amount] that the selected [dues] can't absorb.
  ///
  /// Non-zero means the server will reject the receipt with
  /// "Selected invoices cover only Rs X. Select more to cover Rs Y." — so the
  /// form surfaces it before the user ever hits save.
  static double unallocated(double amount, List<InvoiceDue> dues) {
    final remainder = toPaisa(amount) - toPaisa(totalOutstanding(dues));
    return remainder <= 0 ? 0 : fromPaisa(remainder);
  }

  /// Sum of outstanding balances across [dues] — the most a single collection
  /// can settle, and the overpayment cap.
  static double totalOutstanding(List<InvoiceDue> dues) => fromPaisa(
    dues.fold<int>(0, (sum, due) => sum + toPaisa(due.outstanding)),
  );

  /// The server's ordering: `invoiceDate` ascending, ties broken by
  /// `invoiceNumber` ascending.
  static List<InvoiceDue> _oldestFirst(List<InvoiceDue> dues) {
    final sorted = <InvoiceDue>[...dues]..sort((a, b) {
      final byDate = a.invoice.invoiceDate.compareTo(b.invoice.invoiceDate);
      if (byDate != 0) return byDate;
      return a.invoice.number.compareTo(b.invoice.number);
    });
    return sorted;
  }
}


