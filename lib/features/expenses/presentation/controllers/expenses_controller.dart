import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';
import 'package:sales_sphere_erp/features/expenses/domain/repositories/expense_repository.dart';
// `expenses_providers.dart` re-exports `expenseRepositoryProvider`
// so the controller stays out of `features/.../data/`.
import 'package:sales_sphere_erp/features/expenses/presentation/providers/expenses_providers.dart';

part 'expenses_controller.g.dart';

/// Routes expense-claim write actions from the UI through the repository.
/// Reads stay on `expenseClaimsListProvider` and `expenseClaimByIdProvider`.
///
/// On success the controller patches the list notifier directly
/// (`prependLocal` / `replaceLocal`) instead of invalidating it — an
/// in-place patch keeps the new/edited row visible without a full
/// refetch (and without losing the user's scroll position).
///
/// Each write method opens a `ref.keepAlive()` link for the duration of
/// its in-flight `await` and closes it in `finally`, keeping the notifier
/// (and its `ref`) valid through the post-await state patch without
/// permanently pinning a write-only controller in memory.
@riverpod
class ExpensesController extends _$ExpensesController {
  @override
  void build() {}

  /// Persists a new claim (+ its receipts). On a partial receipt-upload
  /// failure the claim row still exists, so the carried row is prepended
  /// optimistically before the [PartialImageUploadException] is re-thrown
  /// for the page to surface.
  Future<ExpenseClaim> addClaim(ExpenseClaim draft) async {
    final link = ref.keepAlive();
    try {
      final created = await ref.read(expenseRepositoryProvider).addClaim(draft);
      ref.read(expenseClaimsListProvider.notifier).prependLocal(created);
      return created;
    } on PartialImageUploadException catch (e) {
      ref.read(expenseClaimsListProvider.notifier).prependLocal(e.claim);
      rethrow;
    } finally {
      link.close();
    }
  }

  Future<ExpenseClaim> updateClaim(ExpenseClaim claim) async {
    final link = ref.keepAlive();
    try {
      final updated =
          await ref.read(expenseRepositoryProvider).updateClaim(claim);
      ref.read(expenseClaimsListProvider.notifier).replaceLocal(updated);
      return updated;
    } finally {
      link.close();
    }
  }
}
