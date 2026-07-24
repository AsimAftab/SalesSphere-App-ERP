import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_allocation.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';

Collection _collection({
  required double amount,
  List<CollectionAllocation> allocations = const [],
}) => Collection(
  id: 'col_1',
  allocations: allocations,
  party: const CollectionParty(id: 'p1', name: 'Himalayan', address: ''),
  amount: amount,
  receivedDate: DateTime(2026, 7, 11),
  paymentMode: PaymentMode.cash,
  createdAt: DateTime(2026, 7, 11),
);

CollectionAllocation _alloc(double amount) => CollectionAllocation(
  invoiceId: 'inv_$amount',
  invoiceNumber: 'ORD-2026-0001',
  amount: amount,
);

void main() {
  // The server derives `unallocatedAmount` as amount − Σ allocations, floored
  // at zero and rendered to 2dp. These assert the client recomputes the same
  // figure, so an offline read agrees with an online one.
  group('Collection.unallocatedAmount mirrors the wire field', () {
    test('a fully allocated receipt carries no advance', () {
      final c = _collection(
        amount: 1000,
        allocations: [_alloc(600), _alloc(400)],
      );
      expect(c.unallocatedAmount, 0);
      expect(c.hasAdvance, isFalse);
    });

    test('a receipt with no invoices is entirely an advance', () {
      final c = _collection(amount: 1500);
      expect(c.unallocatedAmount, 1500);
      expect(c.hasAdvance, isTrue);
    });

    test('an overshoot leaves the remainder on account', () {
      final c = _collection(amount: 1000, allocations: [_alloc(750)]);
      expect(c.unallocatedAmount, 250);
      expect(c.hasAdvance, isTrue);
    });

    test('floors at zero rather than reporting a negative advance', () {
      final c = _collection(amount: 500, allocations: [_alloc(800)]);
      expect(c.unallocatedAmount, 0);
      expect(c.hasAdvance, isFalse);
    });

    test('rounds to 2dp so float drift never leaks a phantom advance', () {
      // 0.1 + 0.2 == 0.30000000000000004 in IEEE-754; without the rounding
      // this reports a ~4e-17 advance and `hasAdvance` flips true.
      final c = _collection(
        amount: 0.3,
        allocations: [_alloc(0.1), _alloc(0.2)],
      );
      expect(c.unallocatedAmount, 0);
      expect(c.hasAdvance, isFalse);
    });
  });
}
