import 'package:sales_sphere_erp/features/collection_plus/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_allocation.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_invoice.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection_plus/domain/payment_mode.dart';

/// Hard-coded data used to drive the collection UI while there is no
/// collections API. Replace these lists with repository reads when the
/// feature is wired to the backend.

/// Mock parties backing the "Select party" bottom sheet. Slim stand-ins
/// for the real parties feature (which is backend-backed). Names mirror
/// the expenses mock corpus so the two features read consistently.
const kMockCollectionPlusParties = <CollectionPlusParty>[
  CollectionPlusParty(
    id: 'party_himalayan',
    name: 'Himalayan Traders',
    address: 'New Road, Kathmandu',
    ownerName: 'Ram Shrestha',
  ),
  CollectionPlusParty(
    id: 'party_everest',
    name: 'Everest Hardware',
    address: 'Lakeside, Pokhara',
    ownerName: 'Sita Gurung',
  ),
  CollectionPlusParty(
    id: 'party_sagarmatha',
    name: 'Sagarmatha Suppliers',
    address: 'Biratnagar, Morang',
    ownerName: 'Hari Limbu',
  ),
  CollectionPlusParty(
    id: 'party_annapurna',
    name: 'Annapurna Builders',
    address: 'Butwal, Rupandehi',
    ownerName: 'Gita Thapa',
  ),
  CollectionPlusParty(
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

/// Posted invoices a collection can be booked against — the outstanding
/// pool the form allocates payments across.
///
/// Collection Plus is still mock-only while orders/catalog have moved to
/// the live backend. The orders history now carries real server ids, so it
/// can no longer supply invoices whose ids/parties match the mock
/// collections below. This self-contained corpus keeps that linkage:
/// every [CollectionPlusAllocation.invoiceId] in [kMockCollectionPlusList]
/// (`inv_1002`, `inv_1006`, `inv_1007`, `inv_1008`) resolves here, and each
/// invoice's `partyId` matches the collection's party. Grand totals sit
/// above the seeded part-payments so each still shows an outstanding
/// balance, and a few fully-unpaid invoices give every party a realistic
/// list to collect against. Swap for a repository read when the feature is
/// wired to the backend.
final kMockCollectionPlusInvoices = <CollectionPlusInvoice>[
  // Everest Hardware — inv_1002 is the target of col_1004 + col_1005.
  CollectionPlusInvoice(
    id: 'inv_1002',
    number: 'ORD-2026-0002',
    amount: 18000,
    invoiceDate: DateTime(2026, 5, 10),
    partyId: kMockCollectionPlusParties[1].id,
    partyName: kMockCollectionPlusParties[1].name,
  ),
  CollectionPlusInvoice(
    id: 'inv_1012',
    number: 'ORD-2026-0012',
    amount: 9000,
    invoiceDate: DateTime(2026, 6, 5),
    partyId: kMockCollectionPlusParties[1].id,
    partyName: kMockCollectionPlusParties[1].name,
  ),
  // Himalayan Traders — inv_1006 is the target of col_1003.
  CollectionPlusInvoice(
    id: 'inv_1006',
    number: 'ORD-2026-0006',
    amount: 15000,
    invoiceDate: DateTime(2026, 5, 12),
    partyId: kMockCollectionPlusParties[0].id,
    partyName: kMockCollectionPlusParties[0].name,
  ),
  CollectionPlusInvoice(
    id: 'inv_1010',
    number: 'ORD-2026-0010',
    amount: 22000,
    invoiceDate: DateTime(2026, 6, 2),
    partyId: kMockCollectionPlusParties[0].id,
    partyName: kMockCollectionPlusParties[0].name,
  ),
  // Sagarmatha Suppliers — inv_1007 is the target of col_1002.
  CollectionPlusInvoice(
    id: 'inv_1007',
    number: 'ORD-2026-0007',
    amount: 75000,
    invoiceDate: DateTime(2026, 5, 15),
    partyId: kMockCollectionPlusParties[2].id,
    partyName: kMockCollectionPlusParties[2].name,
  ),
  CollectionPlusInvoice(
    id: 'inv_1013',
    number: 'ORD-2026-0013',
    amount: 30000,
    invoiceDate: DateTime(2026, 6, 7),
    partyId: kMockCollectionPlusParties[2].id,
    partyName: kMockCollectionPlusParties[2].name,
  ),
  // Machhapuchhre Cement — inv_1008 is the target of col_1001.
  CollectionPlusInvoice(
    id: 'inv_1008',
    number: 'ORD-2026-0008',
    amount: 12000,
    invoiceDate: DateTime(2026, 5, 18),
    partyId: kMockCollectionPlusParties[4].id,
    partyName: kMockCollectionPlusParties[4].name,
  ),
  CollectionPlusInvoice(
    id: 'inv_1011',
    number: 'ORD-2026-0011',
    amount: 5000,
    invoiceDate: DateTime(2026, 6, 3),
    partyId: kMockCollectionPlusParties[4].id,
    partyName: kMockCollectionPlusParties[4].name,
  ),
  // Annapurna Builders — no seeded collection, but give it an outstanding
  // list so picking it in the Add form has something to allocate against.
  CollectionPlusInvoice(
    id: 'inv_1009',
    number: 'ORD-2026-0009',
    amount: 40000,
    invoiceDate: DateTime(2026, 5, 20),
    partyId: kMockCollectionPlusParties[3].id,
    partyName: kMockCollectionPlusParties[3].name,
  ),
  CollectionPlusInvoice(
    id: 'inv_1014',
    number: 'ORD-2026-0014',
    amount: 18000,
    invoiceDate: DateTime(2026, 6, 9),
    partyId: kMockCollectionPlusParties[3].id,
    partyName: kMockCollectionPlusParties[3].name,
  ),
];

/// Seed collections so the list screen isn't empty on first open. Dates
/// are fixed (not `DateTime.now()`) so the mock corpus is deterministic.
/// Modes are spread across the set so every filter chip and conditional
/// layout (cash / cheque / bank transfer / QR) has at least one row.
///
/// Each allocation books a *partial* payment against a delivery-completed
/// invoice in the orders mock corpus (`order_mock_data.dart`) — same id +
/// number — so the invoice still shows an outstanding balance the form
/// can collect against. Amounts sit below each invoice's VAT-inclusive
/// grand total. `col_1004` + `col_1005` are two part-payments against the
/// same Everest invoice (`inv_1002`).
final kMockCollectionPlusList = <CollectionPlus>[
  CollectionPlus(
    id: 'col_1001',
    allocations: const <CollectionPlusAllocation>[
      CollectionPlusAllocation(
        invoiceId: 'inv_1008',
        invoiceNumber: 'ORD-2026-0008',
        amount: 6200,
      ),
    ],
    party: kMockCollectionPlusParties[4],
    amount: 6200,
    receivedDate: DateTime(2026, 6, 21),
    paymentMode: PaymentMode.qrPay,
    description: 'Scanned QR at site visit.',
    createdAt: DateTime(2026, 6, 21, 15, 30),
  ),
  CollectionPlus(
    id: 'col_1002',
    allocations: const <CollectionPlusAllocation>[
      CollectionPlusAllocation(
        invoiceId: 'inv_1007',
        invoiceNumber: 'ORD-2026-0007',
        amount: 40000,
      ),
    ],
    party: kMockCollectionPlusParties[2],
    amount: 40000,
    receivedDate: DateTime(2026, 6, 20),
    paymentMode: PaymentMode.bankTransfer,
    bankName: 'Nabil Bank',
    description: 'Part payment via bank transfer.',
    createdAt: DateTime(2026, 6, 20, 9, 45),
  ),
  CollectionPlus(
    id: 'col_1003',
    allocations: const <CollectionPlusAllocation>[
      CollectionPlusAllocation(
        invoiceId: 'inv_1006',
        invoiceNumber: 'ORD-2026-0006',
        amount: 8000,
      ),
    ],
    party: kMockCollectionPlusParties[0],
    amount: 8000,
    receivedDate: DateTime(2026, 6, 19),
    paymentMode: PaymentMode.cheque,
    bankName: 'Global IME Bank',
    chequeNumber: 'CHQ-0098231',
    chequeDate: DateTime(2026, 6, 22),
    chequeStatus: ChequeStatus.pending,
    description: 'Post-dated cheque against the marble order.',
    createdAt: DateTime(2026, 6, 19, 11, 5),
  ),
  CollectionPlus(
    id: 'col_1004',
    allocations: const <CollectionPlusAllocation>[
      CollectionPlusAllocation(
        invoiceId: 'inv_1002',
        invoiceNumber: 'ORD-2026-0002',
        amount: 5000,
      ),
    ],
    party: kMockCollectionPlusParties[1],
    amount: 5000,
    receivedDate: DateTime(2026, 6, 14),
    paymentMode: PaymentMode.cash,
    description: 'Cash part-payment against the outstanding balance.',
    createdAt: DateTime(2026, 6, 14, 17, 20),
  ),
  CollectionPlus(
    id: 'col_1005',
    allocations: const <CollectionPlusAllocation>[
      CollectionPlusAllocation(
        invoiceId: 'inv_1002',
        invoiceNumber: 'ORD-2026-0002',
        amount: 6000,
      ),
    ],
    party: kMockCollectionPlusParties[1],
    amount: 6000,
    receivedDate: DateTime(2026, 6, 12),
    paymentMode: PaymentMode.cheque,
    bankName: 'NIC Asia Bank',
    chequeNumber: 'CHQ-0044120',
    chequeDate: DateTime(2026, 6, 12),
    chequeStatus: ChequeStatus.cleared,
    createdAt: DateTime(2026, 6, 12, 13),
  ),
  CollectionPlus(
    id: 'col_1006',
    allocations: const <CollectionPlusAllocation>[
      CollectionPlusAllocation(
        invoiceId: 'inv_1008',
        invoiceNumber: 'ORD-2026-0008',
        amount: 3000,
      ),
    ],
    party: kMockCollectionPlusParties[4],
    amount: 3000,
    receivedDate: DateTime(2026, 6, 10),
    paymentMode: PaymentMode.cash,
    description: 'Initial cash deposit for cement order.',
    createdAt: DateTime(2026, 6, 10, 14, 0),
  ),
  CollectionPlus(
    id: 'col_1007',
    allocations: const <CollectionPlusAllocation>[
      CollectionPlusAllocation(
        invoiceId: 'inv_1007',
        invoiceNumber: 'ORD-2026-0007',
        amount: 20000,
      ),
    ],
    party: kMockCollectionPlusParties[2],
    amount: 20000,
    receivedDate: DateTime(2026, 6, 8),
    paymentMode: PaymentMode.bankTransfer,
    bankName: 'Nabil Bank',
    description: 'First advance transfer.',
    createdAt: DateTime(2026, 6, 8, 11, 30),
  ),
  CollectionPlus(
    id: 'col_1008',
    allocations: const <CollectionPlusAllocation>[
      CollectionPlusAllocation(
        invoiceId: 'inv_1006',
        invoiceNumber: 'ORD-2026-0006',
        amount: 4000,
      ),
    ],
    party: kMockCollectionPlusParties[0],
    amount: 4000,
    receivedDate: DateTime(2026, 6, 11),
    paymentMode: PaymentMode.qrPay,
    description: 'QR payment for marble advance.',
    createdAt: DateTime(2026, 6, 11, 16, 15),
  ),
];
