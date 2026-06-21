import 'package:sales_sphere_erp/features/expenses/data/dto/expense_claim_dto.dart';

/// One paginated slice of `GET /expense-claims/my-requests`. The wire
/// envelope carries `items`, `hasMore`, and `nextCursor` — the API
/// extracts those into this shape so callers don't have to.
class ExpenseClaimsPageDto {
  const ExpenseClaimsPageDto({required this.items, this.nextCursor});

  final List<ExpenseClaimDto> items;
  final String? nextCursor;
}
