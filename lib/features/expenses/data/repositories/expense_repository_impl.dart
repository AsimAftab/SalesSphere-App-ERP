import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/expenses/data/dto/expense_claim_dto.dart';
import 'package:sales_sphere_erp/features/expenses/data/dto/expense_claim_image_ref.dart';
import 'package:sales_sphere_erp/features/expenses/data/expenses_api.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claims_page.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_party.dart';
import 'package:sales_sphere_erp/features/expenses/domain/repositories/expense_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO ↔ domain mapping happens here, plus translation of the
/// backend's error envelope into the app's [ApiException] hierarchy.
class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl({required ExpensesApi api}) : _api = api;

  final ExpensesApi _api;

  @override
  Future<ExpenseClaimsPage> getClaimsPage({
    int limit = 15,
    String? cursor,
    ExpenseClaimStatus? status,
    String? search,
  }) async {
    final pageDto = await _api.listMine(
      limit: limit,
      cursor: cursor,
      status: status == null ? null : _statusToWire(status),
      search: search,
    );
    final items = pageDto.items.map(_toDomain).toList(growable: false);
    return ExpenseClaimsPage(items: items, nextCursor: pageDto.nextCursor);
  }

  /// Creates the claim via `POST /expense-claims`, then best-effort
  /// uploads each attached local receipt to its 1-indexed slot. Image
  /// failures are collected and surfaced as [PartialImageUploadException]
  /// so the form can still navigate forward (the claim row exists) while
  /// telling the user which uploads didn't take.
  @override
  Future<ExpenseClaim> addClaim(ExpenseClaim draft) async {
    final ExpenseClaimDto created;
    try {
      created = await _api.create(_toDto(draft));
    } on DioException catch (e) {
      _throwWriteError(e);
    }
    final domain = _toDomain(created);

    final failures = <int, String>{};
    for (var i = 0; i < draft.imagePaths.length; i++) {
      try {
        await _api.uploadImage(
          claimId: created.id,
          filePath: draft.imagePaths[i],
          imageNumber: i + 1,
        );
      } on DioException catch (e) {
        failures[i + 1] = extractBackendErrorMessage(e) ?? 'Upload failed';
      }
    }
    if (failures.isNotEmpty) {
      throw PartialImageUploadException(claim: domain, failures: failures);
    }
    return domain;
  }

  @override
  Future<ExpenseClaim> updateClaim(ExpenseClaim claim) async {
    try {
      final updated = await _api.update(_toDto(claim));
      return _toDomain(updated);
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  @override
  Future<List<ExpenseClaimImageRef>> listImages(String claimId) =>
      _api.listImages(claimId);

  @override
  Future<ExpenseClaimImageRef> uploadImage({
    required String claimId,
    required String filePath,
    required int slot,
  }) =>
      _api.uploadImage(
        claimId: claimId,
        filePath: filePath,
        imageNumber: slot,
      );

  @override
  Future<void> removeImage({
    required String claimId,
    required int slot,
  }) =>
      _api.removeImage(claimId: claimId, imageNumber: slot);

  @override
  Future<List<String>> getCategories() => _api.categories();

  // ── Mappers ───────────────────────────────────────────────────────────────

  ExpenseClaim _toDomain(ExpenseClaimDto dto) => ExpenseClaim(
    id: dto.id,
    title: dto.title,
    amount: dto.amount,
    date: dto.date,
    category: dto.category,
    status: _statusFromWire(dto.status),
    // The embedded `party { id, companyName }` is the label source; the
    // address isn't on the wire, so it stays empty (it only feeds the
    // picker's subtitle, never the claim view).
    party: dto.party == null
        ? null
        : ExpenseParty(
            id: dto.party!.id,
            name: dto.party!.companyName,
            address: '',
          ),
    description: dto.description,
    rejectionReason: dto.rejectionReason,
    createdAt: dto.createdAt,
  );

  ExpenseClaimDto _toDto(ExpenseClaim c) => ExpenseClaimDto(
    id: c.id,
    title: c.title,
    amount: c.amount,
    date: c.date,
    category: c.category,
    status: _statusToWire(c.status),
    description: c.description,
    createdAt: c.createdAt,
    partyId: c.party?.id,
    party: c.party == null
        ? null
        : ExpenseClaimPartyDto(id: c.party!.id, companyName: c.party!.name),
    rejectionReason: c.rejectionReason,
  );

  ExpenseClaimStatus _statusFromWire(String wire) {
    switch (wire) {
      case 'PENDING':
        return ExpenseClaimStatus.pending;
      case 'APPROVED':
        return ExpenseClaimStatus.approved;
      case 'REJECTED':
        return ExpenseClaimStatus.rejected;
      default:
        throw FormatException('Unsupported expense-claim status: $wire');
    }
  }

  String _statusToWire(ExpenseClaimStatus s) => switch (s) {
    ExpenseClaimStatus.pending => 'PENDING',
    ExpenseClaimStatus.approved => 'APPROVED',
    ExpenseClaimStatus.rejected => 'REJECTED',
  };

  // ── Error translation ───────────────────────────────────────────────────

  /// Re-throws write failures as the app's [ApiException] hierarchy,
  /// preferring the backend's specific message ("no longer pending",
  /// "party not found", etc.) over the interceptor's generic copy — the
  /// interceptor can't reach into our nested `{error:{message}}` envelope.
  Never _throwWriteError(DioException e) {
    final backendMsg = extractBackendErrorMessage(e);
    final mapped = e.error;
    if (mapped is ApiException) {
      if (backendMsg == null || backendMsg == mapped.message) throw mapped;
      switch (mapped) {
        case ValidationException():
          throw ValidationException(backendMsg);
        case ForbiddenException():
          throw ForbiddenException(backendMsg);
        case NotFoundException():
          throw NotFoundException(backendMsg);
        case ServerException():
          throw ServerException(backendMsg, mapped.statusCode ?? 500);
        case NetworkException():
          throw NetworkException(backendMsg, statusCode: mapped.statusCode);
        default:
          throw mapped;
      }
    }
    throw e;
  }
}

/// Exposes the abstract type so consumers depend on the contract, not the
/// impl class. Tests override this provider with a fake `ExpenseRepository`.
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl(api: ref.watch(expensesApiProvider));
});
