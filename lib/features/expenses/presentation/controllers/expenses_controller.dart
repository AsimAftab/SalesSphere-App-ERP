import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/expenses/domain/expense_category.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_party.dart';
import 'package:sales_sphere_erp/features/expenses/presentation/providers/expenses_providers.dart';

part 'expenses_controller.g.dart';

/// Routes expense-claim write actions from the UI into the in-memory
/// store. Reads stay on [expenseClaimsListProvider].
///
/// Mock-only: there's no repository / network yet, so [addClaim] just
/// stamps an id + `createdAt` onto the draft and prepends it to the
/// list. When a backend lands this gains a repository dependency and
/// the body becomes a `repo.addClaim(draft)` call, same as
/// `NotesController.addNote`.
@riverpod
class ExpensesController extends _$ExpensesController {
  @override
  void build() {}

  /// Persists a new claim. Mock-only: stamps an id + `createdAt` and
  /// forces `pending` status (a new claim always starts in the
  /// approval queue, regardless of the draft's value) before
  /// prepending it to the list.
  Future<ExpenseClaim> addClaim({
    required String title,
    required double amount,
    required DateTime date,
    required ExpenseCategory category,
    ExpenseParty? party,
    String description = '',
    List<String> imagePaths = const <String>[],
  }) async {
    final now = DateTime.now();
    final created = ExpenseClaim(
      id: 'exp_${now.microsecondsSinceEpoch}',
      title: title,
      amount: amount,
      date: date,
      category: category,
      status: ExpenseClaimStatus.pending,
      party: party,
      description: description,
      imagePaths: imagePaths,
      createdAt: now,
    );
    ref.read(expenseClaimsListProvider.notifier).prependLocal(created);
    return created;
  }

  /// Persists edits to an existing claim. Mock-only: writes the row
  /// straight back into the in-memory list.
  Future<ExpenseClaim> updateClaim(ExpenseClaim claim) async {
    ref.read(expenseClaimsListProvider.notifier).replaceLocal(claim);
    return claim;
  }
}
