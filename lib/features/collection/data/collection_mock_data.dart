import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
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

/// Seed collections so the list screen isn't empty on first open. Dates
/// are fixed (not `DateTime.now()`) so the mock corpus is deterministic.
/// Modes are spread across the set so every filter chip and conditional
/// layout (cash / cheque / bank transfer / QR) has at least one row.
///
/// These are plain on-account receipts — collected against the party,
/// not booked against any invoice.
final kMockCollectionList = <Collection>[
  Collection(
    id: 'col_1001',
    party: kMockCollectionParties[4],
    amount: 6200,
    receivedDate: DateTime(2026, 6, 21),
    paymentMode: PaymentMode.qrPay,
    description: 'Scanned QR at site visit.',
    createdAt: DateTime(2026, 6, 21, 15, 30),
  ),
  Collection(
    id: 'col_1002',
    party: kMockCollectionParties[2],
    amount: 40000,
    receivedDate: DateTime(2026, 6, 20),
    paymentMode: PaymentMode.bankTransfer,
    bankName: 'Nabil Bank',
    description: 'Part payment via bank transfer.',
    createdAt: DateTime(2026, 6, 20, 9, 45),
  ),
  Collection(
    id: 'col_1003',
    party: kMockCollectionParties[0],
    amount: 8000,
    receivedDate: DateTime(2026, 6, 19),
    paymentMode: PaymentMode.cheque,
    bankName: 'Global IME Bank',
    chequeNumber: 'CHQ-0098231',
    chequeDate: DateTime(2026, 6, 22),
    chequeStatus: ChequeStatus.pending,
    description: 'Post-dated cheque against the outstanding balance.',
    createdAt: DateTime(2026, 6, 19, 11, 5),
  ),
  Collection(
    id: 'col_1004',
    party: kMockCollectionParties[1],
    amount: 5000,
    receivedDate: DateTime(2026, 6, 14),
    paymentMode: PaymentMode.cash,
    description: 'Cash part-payment against the outstanding balance.',
    createdAt: DateTime(2026, 6, 14, 17, 20),
  ),
  Collection(
    id: 'col_1005',
    party: kMockCollectionParties[1],
    amount: 6000,
    receivedDate: DateTime(2026, 6, 12),
    paymentMode: PaymentMode.cheque,
    bankName: 'NIC Asia Bank',
    chequeNumber: 'CHQ-0044120',
    chequeDate: DateTime(2026, 6, 12),
    chequeStatus: ChequeStatus.cleared,
    createdAt: DateTime(2026, 6, 12, 13),
  ),
];
