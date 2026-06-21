import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_invoice.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';

/// Hard-coded data used to drive the collection UI while there is no
/// collections API. Replace these lists with repository reads when the
/// feature is wired to the backend.

/// Mock parties backing the "Select party" bottom sheet. Slim stand-ins
/// for the real parties feature (which is backend-backed). Names mirror
/// the expenses mock corpus so the two features read consistently.
const kMockCollectionParties = <CollectionParty>[
  CollectionParty(
    id: 'party_himalayan',
    name: 'Himalayan Traders',
    address: 'New Road, Kathmandu',
    ownerName: 'Ram Shrestha',
  ),
  CollectionParty(
    id: 'party_everest',
    name: 'Everest Hardware',
    address: 'Lakeside, Pokhara',
    ownerName: 'Sita Gurung',
  ),
  CollectionParty(
    id: 'party_sagarmatha',
    name: 'Sagarmatha Suppliers',
    address: 'Biratnagar, Morang',
    ownerName: 'Hari Limbu',
  ),
  CollectionParty(
    id: 'party_annapurna',
    name: 'Annapurna Builders',
    address: 'Butwal, Rupandehi',
    ownerName: 'Gita Thapa',
  ),
  CollectionParty(
    id: 'party_machhapuchhre',
    name: 'Machhapuchhre Cement',
    address: 'Hetauda, Makwanpur',
    ownerName: 'Bikash Tamang',
  ),
];

/// Banks offered in the bank-name picker (cheque / bank transfer).
/// Stands in for v1's `/collections/utils/bank-names` endpoint; the
/// picker also lets the user add a bank that isn't on the list.
const kMockBankNames = <String>[
  'Nabil Bank',
  'Nepal Investment Mega Bank',
  'Global IME Bank',
  'NIC Asia Bank',
  'Standard Chartered Nepal',
  'Himalayan Bank',
  'Prabhu Bank',
  'Siddhartha Bank',
  'Kumari Bank',
  'Laxmi Sunrise Bank',
];

/// Posted invoices the seed collections are booked against. These mirror
/// the delivery-`completed`, `kind: order` records in the orders mock
/// corpus (`order_mock_data.dart`) — same id + number + party — so a seed
/// collection links to a real invoice the picker also surfaces. A
/// collection is only booked once delivery is complete, so each
/// collection's `receivedDate` is on/after its invoice's delivery.
const _invMachhapuchhre = CollectionInvoice(
  id: 'inv_1008',
  number: 'ORD-2026-0008',
  amount: 64000,
  partyId: 'party_machhapuchhre',
  partyName: 'Machhapuchhre Cement',
);
const _invSagarmatha = CollectionInvoice(
  id: 'inv_1007',
  number: 'ORD-2026-0007',
  amount: 75500,
  partyId: 'party_sagarmatha',
  partyName: 'Sagarmatha Suppliers',
);
const _invHimalayan = CollectionInvoice(
  id: 'inv_1006',
  number: 'ORD-2026-0006',
  amount: 120000,
  partyId: 'party_himalayan',
  partyName: 'Himalayan Traders',
);
const _invEverest = CollectionInvoice(
  id: 'inv_1002',
  number: 'ORD-2026-0002',
  amount: 98000,
  partyId: 'party_everest',
  partyName: 'Everest Hardware',
);

/// Seed collections so the list screen isn't empty on first open. Dates
/// are fixed (not `DateTime.now()`) so the mock corpus is deterministic.
/// Modes are spread across the set so every filter chip and conditional
/// layout (cash / cheque / bank transfer / QR) has at least one row, and
/// each row links to a delivery-completed invoice (col_1004 + col_1005
/// are two part-payments against the same invoice).
final kMockCollections = <Collection>[
  Collection(
    id: 'col_1001',
    invoice: _invMachhapuchhre,
    party: kMockCollectionParties[4],
    amount: 6200,
    receivedDate: DateTime(2026, 6, 21),
    paymentMode: PaymentMode.qrPay,
    description: 'Scanned QR at site visit.',
    createdAt: DateTime(2026, 6, 21, 15, 30),
  ),
  Collection(
    id: 'col_1002',
    invoice: _invSagarmatha,
    party: kMockCollectionParties[2],
    amount: 75500,
    receivedDate: DateTime(2026, 6, 20),
    paymentMode: PaymentMode.bankTransfer,
    bankName: 'Nabil Bank',
    description: 'Direct transfer — invoice settled in full.',
    createdAt: DateTime(2026, 6, 20, 9, 45),
  ),
  Collection(
    id: 'col_1003',
    invoice: _invHimalayan,
    party: kMockCollectionParties[0],
    amount: 48000,
    receivedDate: DateTime(2026, 6, 19),
    paymentMode: PaymentMode.cheque,
    bankName: 'Global IME Bank',
    chequeNumber: 'CHQ-0098231',
    chequeDate: DateTime(2026, 6, 22),
    chequeStatus: ChequeStatus.pending,
    description: 'Post-dated cheque against the marble order.',
    createdAt: DateTime(2026, 6, 19, 11, 5),
  ),
  Collection(
    id: 'col_1004',
    invoice: _invEverest,
    party: kMockCollectionParties[1],
    amount: 12500,
    receivedDate: DateTime(2026, 6, 14),
    paymentMode: PaymentMode.cash,
    description: 'Cash part-payment against the outstanding balance.',
    createdAt: DateTime(2026, 6, 14, 17, 20),
  ),
  Collection(
    id: 'col_1005',
    invoice: _invEverest,
    party: kMockCollectionParties[1],
    amount: 31000,
    receivedDate: DateTime(2026, 6, 12),
    paymentMode: PaymentMode.cheque,
    bankName: 'NIC Asia Bank',
    chequeNumber: 'CHQ-0044120',
    chequeDate: DateTime(2026, 6, 12),
    chequeStatus: ChequeStatus.cleared,
    createdAt: DateTime(2026, 6, 12, 13),
  ),
];
