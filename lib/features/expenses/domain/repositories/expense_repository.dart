import 'package:sales_sphere_erp/features/expenses/data/dto/expense_claim_image_ref.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claims_page.dart';

/// Thrown by [ExpenseRepository.addClaim] when the claim row was
/// successfully created but at least one of the attached receipt uploads
/// failed. Carries the created [claim] so callers can still reflect the
/// new row in the UI, plus per-slot [failures] keyed by 1-indexed slot
/// number with the backend's error message (or a generic fallback).
///
/// Hard failures (the claim itself couldn't be created) keep bubbling as
/// the underlying error — those reach the form's generic catch and leave
/// the user on the page to retry.
class PartialImageUploadException implements Exception {
  const PartialImageUploadException({
    required this.claim,
    required this.failures,
  });

  final ExpenseClaim claim;
  final Map<int, String> failures;

  /// 1-indexed slot numbers that failed, in deterministic order so the
  /// form's snackbar copy is stable across runs.
  List<int> get failedSlots => failures.keys.toList()..sort();

  /// Convenience for snackbars: the first failure's backend message, or
  /// the generic fallback when there were none.
  String get firstMessage =>
      failures.isEmpty ? 'Upload failed' : failures.values.first;

  @override
  String toString() =>
      'PartialImageUploadException(claim=${claim.id}, failures=$failures)';
}

/// Domain-side contract for expense-claims data. The concrete
/// implementation (DTO ↔ domain mapping + receipt uploads + error
/// translation) lives in
/// `data/repositories/expense_repository_impl.dart`.
abstract class ExpenseRepository {
  /// One paginated slice of the caller's own claims, newest first. Pass
  /// [cursor] to load the next page; [status] / [search] narrow the list
  /// server-side.
  Future<ExpenseClaimsPage> getClaimsPage({
    int limit,
    String? cursor,
    ExpenseClaimStatus? status,
    String? search,
  });

  /// Persists the claim + attached receipts. On image-only failures,
  /// throws [PartialImageUploadException] carrying the created claim so
  /// the caller can still reflect the new row in the UI.
  Future<ExpenseClaim> addClaim(ExpenseClaim draft);

  /// PENDING-only partial update. 4xxes server-side once the claim is
  /// APPROVED / REJECTED.
  Future<ExpenseClaim> updateClaim(ExpenseClaim claim);

  /// Fetch the claim's current receipts for the edit form's picker to
  /// hydrate. Returns `[]` for a claim with no receipts.
  Future<List<ExpenseClaimImageRef>> listImages(String claimId);

  /// Upload (or replace) one receipt slot.
  Future<ExpenseClaimImageRef> uploadImage({
    required String claimId,
    required String filePath,
    required int slot,
  });

  /// Delete one receipt slot.
  Future<void> removeImage({
    required String claimId,
    required int slot,
  });

  /// The org-managed category catalogue names feeding the picker.
  Future<List<String>> getCategories();
}
