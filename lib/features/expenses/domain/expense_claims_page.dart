import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';

/// One slice of the paginated `GET /expense-claims/my-requests` list
/// returned from the repository. `nextCursor == null` ⇒ the server has no
/// more pages for this query.
class ExpenseClaimsPage {
  const ExpenseClaimsPage({required this.items, this.nextCursor});

  final List<ExpenseClaim> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
