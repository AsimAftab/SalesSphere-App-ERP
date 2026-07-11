import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_party.dart'
    as plus;
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_status.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_mode.dart'
    as plus;

Collection _collection({bool syncPending = false}) => Collection(
  id: 'col_1',
  party: const CollectionParty(id: 'p1', name: 'Himalayan', address: ''),
  amount: 1000,
  receivedDate: DateTime(2026, 7, 11),
  paymentMode: PaymentMode.cash,
  createdAt: DateTime(2026, 7, 11),
  syncPending: syncPending,
);

CollectionPlus _plus({
  CollectionStatus status = CollectionStatus.draft,
  bool syncPending = false,
}) => CollectionPlus(
  id: 'colp_1',
  allocations: const [],
  party: const plus.CollectionPlusParty(
    id: 'p1',
    name: 'Himalayan',
    address: '',
  ),
  amount: 1000,
  receivedDate: DateTime(2026, 7, 11),
  paymentMode: plus.PaymentMode.cash,
  status: status,
  createdAt: DateTime(2026, 7, 11),
  syncPending: syncPending,
);

/// The two modules diverge on exactly one axis: whether there's a ledger entry
/// behind the row. Everything below follows from that.
void main() {
  group('Collection — no ledger, so always editable', () {
    test('a synced collection is editable', () {
      // It used to be gated on `status == DRAFT`. There is no status any more:
      // a plain Collection never posts, so there is nothing to protect and the
      // server allows PATCH/DELETE at any time.
      expect(_collection().isEditable, isTrue);
    });

    test('only a queued row is not editable — it has no server id yet', () {
      expect(_collection(syncPending: true).isEditable, isFalse);
    });
  });

  group('CollectionPlus — has a ledger, so DRAFT-only', () {
    test('a draft is editable', () {
      expect(_plus().isEditable, isTrue);
    });

    test('a posted receipt is not — the server 409s any PATCH', () {
      expect(_plus(status: CollectionStatus.posted).isEditable, isFalse);
    });

    test('a cancelled receipt is not', () {
      expect(_plus(status: CollectionStatus.cancelled).isEditable, isFalse);
    });

    test('a queued draft is not — no server id to address', () {
      expect(_plus(syncPending: true).isEditable, isFalse);
    });
  });
}
