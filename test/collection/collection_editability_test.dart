import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';

Collection _collection({
  CollectionStatus status = CollectionStatus.draft,
  bool syncPending = false,
}) => Collection(
  id: 'colp_1',
  allocations: const [],
  party: const CollectionParty(
    id: 'p1',
    name: 'Himalayan',
    address: '',
  ),
  amount: 1000,
  receivedDate: DateTime(2026, 7, 11),
  paymentMode: PaymentMode.cash,
  status: status,
  createdAt: DateTime(2026, 7, 11),
  syncPending: syncPending,
);

void main() {
  group('Collection — has a ledger, so DRAFT-only', () {
    test('a draft is editable', () {
      expect(_collection().isEditable, isTrue);
    });

    test('a posted receipt is not — the server 409s any PATCH', () {
      expect(_collection(status: CollectionStatus.posted).isEditable, isFalse);
    });

    test('a cancelled receipt is not', () {
      expect(_collection(status: CollectionStatus.cancelled).isEditable, isFalse);
    });

    test('a queued draft is not — no server id to address', () {
      expect(_collection(syncPending: true).isEditable, isFalse);
    });
  });
}
