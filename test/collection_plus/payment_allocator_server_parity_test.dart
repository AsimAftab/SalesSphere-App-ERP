import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_invoice.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/invoice_due.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_allocator.dart';

InvoiceDue _due(
  String number,
  double outstanding, {
  required DateTime date,
  double? total,
}) => InvoiceDue(
  invoice: CollectionPlusInvoice(
    id: 'inv_${number.toLowerCase()}',
    number: number,
    amount: total ?? outstanding,
    invoiceDate: date,
  ),
  paid: (total ?? outstanding) - outstanding,
  outstanding: outstanding,
);

/// The on-device FIFO preview must produce **exactly** the split the server
/// books, or the user is shown one allocation and gets another.
///
/// The server sorts by `invoiceDate` ascending, breaks ties on `invoiceNumber`
/// ascending, and does the arithmetic in integer paisa. These tests pin all
/// three, because each one is a silent-wrong-answer bug rather than a crash.
void main() {
  group('server parity — ordering', () {
    test('allocates oldest-first even when the input is out of order', () {
      // A caller that filtered or concatenated the outstanding list could
      // easily disturb the server's ordering. Sort defensively rather than
      // trusting it.
      final dues = <InvoiceDue>[
        _due('INV-NEW', 30000, date: DateTime(2026, 7)),
        _due('INV-OLD', 20000, date: DateTime(2026, 1)),
      ];

      final result = PaymentAllocator.allocate(25000, dues);

      expect(result.first.invoiceNumber, 'INV-OLD');
      expect(result.first.amount, 20000);
      expect(result[1].invoiceNumber, 'INV-NEW');
      expect(result[1].amount, 5000);
    });

    test('ties on invoiceDate break on invoiceNumber ascending', () {
      // Two invoices raised the same day is entirely ordinary. Without the
      // tie-break the two sides can pick a different one to fill first, and the
      // preview quietly disagrees with the booking.
      final sameDay = DateTime(2026, 3, 15);
      final dues = <InvoiceDue>[
        _due('INV-B', 10000, date: sameDay),
        _due('INV-A', 10000, date: sameDay),
      ];

      final result = PaymentAllocator.allocate(10000, dues);

      expect(result, hasLength(1));
      expect(result.single.invoiceNumber, 'INV-A');
    });
  });

  group('server parity — integer paisa', () {
    test('each slice is exact, and the total reconciles in paisa', () {
      // 0.1 + 0.2 == 0.30000000000000004 in binary floating point. The
      // allocator works in integer paisa so every *slice* is exact — but
      // summing the slices back up as doubles reintroduces the drift. The
      // invariant is "Σ allocations == amount" **in paisa**, and any code
      // reconciling money has to say so. (The server owns the real sum
      // regardless; this only has to be right enough to preview.)
      final dues = <InvoiceDue>[
        _due('INV-A', 0.10, date: DateTime(2026)),
        _due('INV-B', 0.20, date: DateTime(2026, 2)),
      ];

      final result = PaymentAllocator.allocate(0.30, dues);

      expect(result.map((a) => a.amount).toList(), <double>[0.10, 0.20]);

      final totalPaisa = result.fold<int>(
        0,
        (sum, a) => sum + PaymentAllocator.toPaisa(a.amount),
      );
      expect(totalPaisa, PaymentAllocator.toPaisa(0.30));

      // Naively folding in doubles is exactly the trap — pinned so nobody
      // "simplifies" the assertion above back into it.
      final naive = result.fold<double>(0, (sum, a) => sum + a.amount);
      expect(naive, isNot(0.30));

      expect(PaymentAllocator.unallocated(0.30, dues), 0);
    });

    test('allocations sum exactly to the amount when fully covered', () {
      final dues = <InvoiceDue>[
        _due('INV-A', 20000, date: DateTime(2026)),
        _due('INV-B', 20000, date: DateTime(2026, 2)),
        _due('INV-C', 30000, date: DateTime(2026, 3)),
      ];

      // The acceptance case from the backend brief: 50000 over 20/20/30
      // must produce 20000 / 20000 / 10000.
      final result = PaymentAllocator.allocate(50000, dues);

      expect(
        result.map((a) => a.amount).toList(),
        <double>[20000, 20000, 10000],
      );
      expect(
        result.fold<double>(0, (sum, a) => sum + a.amount),
        50000,
      );
    });
  });

  group('coverage shortfall', () {
    test('unallocated reports the gap the server will refuse', () {
      // 90000 against 70000 of coverage → the server 422s with
      // "Selected invoices cover only Rs 70000.00...". The form must catch this
      // before the user hits save.
      final dues = <InvoiceDue>[
        _due('INV-A', 40000, date: DateTime(2026)),
        _due('INV-B', 30000, date: DateTime(2026, 2)),
      ];

      expect(PaymentAllocator.totalOutstanding(dues), 70000);
      expect(PaymentAllocator.unallocated(90000, dues), 20000);
    });

    test('a fully-covered amount leaves nothing unallocated', () {
      final dues = <InvoiceDue>[_due('INV-A', 40000, date: DateTime(2026))];
      expect(PaymentAllocator.unallocated(40000, dues), 0);
    });

    test('a fully-paid invoice is skipped, not allocated zero', () {
      final dues = <InvoiceDue>[
        _due('INV-PAID', 0, date: DateTime(2026), total: 10000),
        _due('INV-OPEN', 5000, date: DateTime(2026, 2)),
      ];

      final result = PaymentAllocator.allocate(5000, dues);

      expect(result, hasLength(1));
      expect(result.single.invoiceNumber, 'INV-OPEN');
    });
  });
}
