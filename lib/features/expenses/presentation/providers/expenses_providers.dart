import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/expenses/data/expenses_mock_data.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_category.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_party.dart';

part 'expenses_providers.g.dart';

/// Categories offered in the category-selection bottom sheet. Synchronous
/// — no API/drift yet (mock-only). Swap for a repository read when the
/// expense-claims feature is wired to the backend.
@riverpod
List<ExpenseCategory> expenseCategories(Ref ref) => kExpenseCategories;

/// Parties offered in the optional "Select party" bottom sheet.
@riverpod
List<ExpenseParty> expenseParties(Ref ref) => kMockExpenseParties;

/// In-memory list of expense claims, seeded from the mock corpus. The
/// list screen watches this directly; the controller prepends new rows
/// after a successful add so the optimistic row appears at the top.
///
/// Async so the list screen has a real loading window to paint a
/// skeleton against (mirrors `NotesList` / the tour-plan list). The
/// short delay stands in for a network fetch — swap `build` for a
/// `repo.getClaims()` call when a backend lands.
@Riverpod(keepAlive: true)
class ExpenseClaimsList extends _$ExpenseClaimsList {
  @override
  Future<List<ExpenseClaim>> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List<ExpenseClaim>.from(kMockExpenseClaims);
  }

  /// Insert [claim] at the head of the list. Called by the controller
  /// after a successful add.
  void prependLocal(ExpenseClaim claim) {
    final current = state.value ?? const <ExpenseClaim>[];
    if (current.any((c) => c.id == claim.id)) return;
    state = AsyncValue<List<ExpenseClaim>>.data(
      <ExpenseClaim>[claim, ...current],
    );
  }

  /// Replace the row matching [claim].id. No-op when the claim isn't
  /// present. Called by the controller after a successful edit.
  void replaceLocal(ExpenseClaim claim) {
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((c) => c.id == claim.id);
    if (idx == -1) return;
    final next = <ExpenseClaim>[...current];
    next[idx] = claim;
    state = AsyncValue<List<ExpenseClaim>>.data(next);
  }

  /// Pull-to-refresh. Mock-only: there's no backend to re-fetch from,
  /// so this simulates a network round-trip and re-emits the current
  /// list (locally-added / edited rows are preserved). When a backend
  /// lands this becomes a real `repo.getClaims()` call.
  Future<void> refresh() async {
    final current = state.value ?? const <ExpenseClaim>[];
    await Future<void>.delayed(const Duration(milliseconds: 600));
    state = AsyncValue<List<ExpenseClaim>>.data(<ExpenseClaim>[...current]);
  }
}

/// Resolves a single claim by id from the loaded list. Returns `null`
/// when the list hasn't resolved yet or the id isn't present (deep-link
/// callers pass the claim via `extra` to avoid the former).
@riverpod
ExpenseClaim? expenseClaimById(Ref ref, String id) {
  final claims = ref.watch(expenseClaimsListProvider).value ??
      const <ExpenseClaim>[];
  for (final claim in claims) {
    if (claim.id == id) return claim;
  }
  return null;
}
