import 'package:sales_sphere_erp/features/expenses/domain/expense_category.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_party.dart';

/// Hard-coded data used to drive the expense-claims UI while there is
/// no expense-claims API. Replace these lists with repository reads
/// when the feature is wired to the backend.

/// Categories offered in the category-selection bottom sheet. Mirrors
/// the full [ExpenseCategory] set; named here so the picker has a
/// single source of truth it can render and (later) filter.
const kExpenseCategories = ExpenseCategory.values;

/// Mock parties backing the optional "Select party" bottom sheet. Slim
/// stand-ins for the real parties feature (which is backend-backed).
const kMockExpenseParties = <ExpenseParty>[
  ExpenseParty(
    id: 'party_himalayan',
    name: 'Himalayan Traders',
    address: 'New Road, Kathmandu',
  ),
  ExpenseParty(
    id: 'party_everest',
    name: 'Everest Hardware',
    address: 'Lakeside, Pokhara',
  ),
  ExpenseParty(
    id: 'party_sagarmatha',
    name: 'Sagarmatha Suppliers',
    address: 'Biratnagar, Morang',
  ),
  ExpenseParty(
    id: 'party_annapurna',
    name: 'Annapurna Builders',
    address: 'Butwal, Rupandehi',
  ),
  ExpenseParty(
    id: 'party_machhapuchhre',
    name: 'Machhapuchhre Cement',
    address: 'Hetauda, Makwanpur',
  ),
];

/// Seed claims so the list screen isn't empty on first open. Dates are
/// fixed (not `DateTime.now()`) so the mock corpus is deterministic.
/// Statuses are spread across the workflow so every filter chip and
/// status badge has at least one row to render.
final kMockExpenseClaims = <ExpenseClaim>[
  ExpenseClaim(
    id: 'exp_1001',
    title: 'Taxi to client site',
    amount: 850,
    date: DateTime(2026, 6, 16),
    category: ExpenseCategory.travel,
    status: ExpenseClaimStatus.pending,
    party: kMockExpenseParties[0],
    description: 'Round trip to New Road for the quarterly review.',
    createdAt: DateTime(2026, 6, 16, 18, 30),
  ),
  ExpenseClaim(
    id: 'exp_1002',
    title: 'Lunch with distributor',
    amount: 1240,
    date: DateTime(2026, 6, 15),
    category: ExpenseCategory.meals,
    status: ExpenseClaimStatus.approved,
    party: kMockExpenseParties[1],
    createdAt: DateTime(2026, 6, 15, 14, 10),
  ),
  ExpenseClaim(
    id: 'exp_1003',
    title: 'Bike fuel — field route',
    amount: 600,
    date: DateTime(2026, 6, 14),
    category: ExpenseCategory.fuel,
    status: ExpenseClaimStatus.rejected,
    description: 'Pokhara to Damauli and back.',
    rejectionReason: 'Missing fuel receipt — please re-submit with a bill.',
    createdAt: DateTime(2026, 6, 14, 9, 5),
  ),
  ExpenseClaim(
    id: 'exp_1004',
    title: 'Hotel stay — Biratnagar',
    amount: 3500,
    date: DateTime(2026, 6, 10),
    category: ExpenseCategory.accommodation,
    status: ExpenseClaimStatus.approved,
    party: kMockExpenseParties[2],
    createdAt: DateTime(2026, 6, 10, 20),
  ),
];
