import 'package:sales_sphere_erp/features/catalog/data/catalog_mock_data.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_line_item.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_organization.dart';
import 'package:sales_sphere_erp/features/invoice/domain/invoice_party.dart';
import 'package:sales_sphere_erp/features/invoice/domain/tax_option.dart';

/// Hard-coded data used to drive the invoice UI while there is no invoice
/// API. Replace these lists with repository reads when the feature is
/// wired to the backend.

/// Tax lines offered in the invoice's tax picker. `No Tax` first so it is
/// the default selection.
const kTaxOptions = <TaxOption>[
  TaxOption(id: 'none', label: 'No Tax', rate: 0),
  TaxOption(id: 'vat13', label: 'VAT 13%', rate: 13),
];

/// Preselected tax for a fresh draft.
const kDefaultTaxOption = TaxOption(id: 'none', label: 'No Tax', rate: 0);

/// The selling organisation rendered as the "From" party on the invoice
/// detail page. Hard-coded while invoice is mock-only — replace with the
/// authenticated tenant's profile when the backend lands.
const kMockInvoiceOrganization = InvoiceOrganization(
  name: 'SalesSphere Distributors Pvt. Ltd.',
  panVat: '301234567',
  phone: '01-4567890',
  address: 'Tinkune, Kathmandu, Nepal',
);

/// Mock parties backing the searchable "Select party" sheet. Slim
/// stand-ins for the real (backend-backed) parties feature; each carries
/// an [InvoiceParty.ownerName] so the invoice's owner field can auto-fill.
const kMockInvoiceParties = <InvoiceParty>[
  InvoiceParty(
    id: 'party_himalayan',
    name: 'Himalayan Traders',
    ownerName: 'Ram Shrestha',
    address: 'New Road, Kathmandu',
    panVat: '601234567',
    phone: '98510 12345',
  ),
  InvoiceParty(
    id: 'party_everest',
    name: 'Everest Hardware',
    ownerName: 'Sita Gurung',
    address: 'Lakeside, Pokhara',
    panVat: '602345678',
    phone: '98460 23456',
  ),
  InvoiceParty(
    id: 'party_sagarmatha',
    name: 'Sagarmatha Suppliers',
    ownerName: 'Hari Karki',
    address: 'Biratnagar, Morang',
    panVat: '603456789',
    phone: '98420 34567',
  ),
  InvoiceParty(
    id: 'party_annapurna',
    name: 'Annapurna Builders',
    ownerName: 'Gita Thapa',
    address: 'Butwal, Rupandehi',
    panVat: '604567890',
    phone: '98570 45678',
  ),
  InvoiceParty(
    id: 'party_machhapuchhre',
    name: 'Machhapuchhre Cement',
    ownerName: 'Bishnu Adhikari',
    address: 'Hetauda, Makwanpur',
    panVat: '605678901',
    phone: '98550 56789',
  ),
];

/// Builds a line item from a mock product id. [basePrice] defaults to the
/// product's listed price (no discount); pass a lower value to seed a
/// discounted line — the discount % is derived from it.
InvoiceLineItem _seedLine(
  String productId, {
  required int quantity,
  double? basePrice,
}) {
  final product = kMockProducts.firstWhere((p) => p.id == productId);
  return InvoiceLineItem(
    productId: product.id,
    name: product.name,
    imageUrl: product.imageUrl,
    listedPrice: product.price,
    quantity: quantity,
    basePrice: basePrice ?? product.price,
    availableStock: product.stock,
  );
}

/// Seed invoices + estimates so both History tabs render on first open.
/// Dates are fixed (not `DateTime.now()`) so the corpus is deterministic.
/// Numbers seed the per-kind counter (the controller continues from the
/// max existing suffix).
final kMockInvoiceHistory = <Invoice>[
  Invoice(
    id: 'inv_1005',
    number: 'INV-2026-0005',
    kind: InvoiceKind.invoice,
    status: InvoiceStatus.pending,
    party: kMockInvoiceParties[0],
    deliveryDate: DateTime(2026, 6, 24),
    items: <InvoiceLineItem>[
      // 1250 listed -> 1187.50 base ≈ 5% off.
      _seedLine('p_marble_carrara', quantity: 6, basePrice: 1187.5),
      _seedLine('p_san_mixer', quantity: 2),
    ],
    overallDiscountPercent: 2,
    tax: kTaxOptions[1],
    createdAt: DateTime(2026, 6, 17, 11, 20),
  ),
  Invoice(
    id: 'inv_1004',
    number: 'INV-2026-0004',
    kind: InvoiceKind.invoice,
    status: InvoiceStatus.inProgress,
    party: kMockInvoiceParties[4],
    deliveryDate: DateTime(2026, 6, 22),
    items: <InvoiceLineItem>[
      _seedLine('p_paint_exterior', quantity: 5),
      _seedLine('p_cpvc_cement', quantity: 12),
    ],
    overallDiscountPercent: 0,
    tax: kTaxOptions[1],
    createdAt: DateTime(2026, 6, 16, 15, 5),
  ),
  Invoice(
    id: 'inv_1003',
    number: 'INV-2026-0003',
    kind: InvoiceKind.invoice,
    status: InvoiceStatus.inTransit,
    party: kMockInvoiceParties[2],
    deliveryDate: DateTime(2026, 6, 19),
    items: <InvoiceLineItem>[
      _seedLine('p_san_toilet', quantity: 3),
    ],
    overallDiscountPercent: 0,
    tax: kTaxOptions[1],
    createdAt: DateTime(2026, 6, 14, 10),
  ),
  Invoice(
    id: 'inv_1002',
    number: 'INV-2026-0002',
    kind: InvoiceKind.invoice,
    status: InvoiceStatus.completed,
    party: kMockInvoiceParties[1],
    deliveryDate: DateTime(2026, 6, 12),
    items: <InvoiceLineItem>[
      _seedLine('p_paint_emulsion', quantity: 3),
      // 890 listed -> 801 base = 10% off.
      _seedLine('p_paint_primer', quantity: 4, basePrice: 801),
    ],
    overallDiscountPercent: 0,
    tax: kTaxOptions[1],
    createdAt: DateTime(2026, 6, 11, 9, 45),
  ),
  Invoice(
    id: 'inv_1001',
    number: 'INV-2026-0001',
    kind: InvoiceKind.invoice,
    status: InvoiceStatus.rejected,
    party: kMockInvoiceParties[3],
    deliveryDate: DateTime(2026, 6, 10),
    items: <InvoiceLineItem>[
      _seedLine('p_ply_commercial', quantity: 8),
    ],
    overallDiscountPercent: 0,
    tax: kTaxOptions[1],
    createdAt: DateTime(2026, 6, 8, 13, 30),
  ),
  Invoice(
    id: 'est_1002',
    number: 'EST-2026-0002',
    kind: InvoiceKind.estimate,
    status: InvoiceStatus.pending,
    party: kMockInvoiceParties[3],
    deliveryDate: DateTime(2026, 6, 25),
    items: <InvoiceLineItem>[
      // 2650 listed -> 2464.5 base ≈ 7% off.
      _seedLine('p_ply_marine', quantity: 10, basePrice: 2464.5),
    ],
    overallDiscountPercent: 5,
    tax: kDefaultTaxOption,
    createdAt: DateTime(2026, 6, 15, 16),
  ),
  Invoice(
    id: 'est_1001',
    number: 'EST-2026-0001',
    kind: InvoiceKind.estimate,
    status: InvoiceStatus.completed,
    party: kMockInvoiceParties[1],
    deliveryDate: DateTime(2026, 6, 18),
    items: <InvoiceLineItem>[
      _seedLine('p_cpvc_pipe', quantity: 40),
      _seedLine('p_cpvc_elbow', quantity: 80),
    ],
    overallDiscountPercent: 0,
    tax: kTaxOptions[1],
    createdAt: DateTime(2026, 6, 9, 13, 30),
  ),
];
