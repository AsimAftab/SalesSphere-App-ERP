import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_invoice.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/invoice_due.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_allocator.dart';

InvoiceDue _due(String id, double outstanding, {double? amount}) => InvoiceDue(
      invoice: CollectionPlusInvoice(
        id: id,
        number: id.toUpperCase(),
        amount: amount ?? outstanding,
        invoiceDate: DateTime(2026, 6, 18),
      ),
      paid: (amount ?? outstanding) - outstanding,
      outstanding: outstanding,
    );

void main() {
  group('PaymentAllocator.allocate (FIFO)', () {
    test('a payment within the first invoice lands entirely on it', () {
      final dues = <InvoiceDue>[_due('a', 100000), _due('b', 50000)];

      final result = PaymentAllocator.allocate(40000, dues);

      expect(result, hasLength(1));
      expect(result.single.invoiceId, 'a');
      expect(result.single.amount, 40000);
    });

    test('overflow cascades to the next invoice — the headline scenario', () {
      // 'a' has 50k outstanding (a 100k bill already part-paid 50k), 'b'
      // has 50k. A 60k payment settles 'a' (50k) then spills 10k onto 'b'.
      final dues = <InvoiceDue>[
        _due('a', 50000, amount: 100000),
        _due('b', 50000),
      ];

      final result = PaymentAllocator.allocate(60000, dues);

      expect(result, hasLength(2));
      expect(result[0].invoiceId, 'a');
      expect(result[0].amount, 50000);
      expect(result[1].invoiceId, 'b');
      expect(result[1].amount, 10000);
    });

    test('exact full settlement allocates every invoice to zero', () {
      final dues = <InvoiceDue>[_due('a', 50000), _due('b', 50000)];

      final result = PaymentAllocator.allocate(100000, dues);

      expect(result.map((a) => a.amount).toList(), <double>[50000, 50000]);
    });

    test('a remainder beyond total outstanding is dropped, not allocated', () {
      final dues = <InvoiceDue>[_due('a', 50000)];

      // Callers block this via totalOutstanding; the allocator just caps.
      final result = PaymentAllocator.allocate(70000, dues);

      expect(result, hasLength(1));
      expect(result.single.amount, 50000);
    });

    test('no outstanding invoices yields no allocations', () {
      expect(PaymentAllocator.allocate(1000, const <InvoiceDue>[]), isEmpty);
    });

    test('totalOutstanding sums the dues', () {
      final dues = <InvoiceDue>[_due('a', 50000), _due('b', 12345)];

      expect(PaymentAllocator.totalOutstanding(dues), 62345);
    });
  });
}
