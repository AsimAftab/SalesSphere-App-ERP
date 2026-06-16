import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/leaves/data/dto/leave_dto.dart';
import 'package:sales_sphere_erp/features/leaves/data/leaves_api.dart';
import 'package:sales_sphere_erp/features/leaves/domain/leave.dart';
import 'package:sales_sphere_erp/features/leaves/domain/repositories/leaves_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO ↔ domain mapping happens here, plus translation of the
/// backend's error envelope into the app's [ApiException] hierarchy.
class LeavesRepositoryImpl implements LeavesRepository {
  LeavesRepositoryImpl({required LeavesApi api}) : _api = api;

  final LeavesApi _api;

  @override
  Future<List<Leave>> getLeaves() async {
    final dtos = await _api.listMine();
    final leaves = dtos.map(_toDomain).toList()
      // Newest first — mirror the list page's previous ordering.
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<Leave>.unmodifiable(leaves);
  }

  @override
  Future<Leave> addLeave(Leave draft) async {
    try {
      final created = await _api.create(<String, dynamic>{
        'category': _categoryToWire(draft.category),
        'reason': draft.reason,
        'startDate': _dateToWire(draft.startDate),
        // Omit endDate for a single-day leave — the backend defaults it to
        // startDate.
        if (draft.endDate != null) 'endDate': _dateToWire(draft.endDate!),
      });
      return _toDomain(created);
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  @override
  Future<Leave> updateLeave(Leave leave) async {
    try {
      final updated = await _api.update(leave.id, <String, dynamic>{
        'category': _categoryToWire(leave.category),
        'reason': leave.reason,
        'startDate': _dateToWire(leave.startDate),
        // Always send a concrete endDate on update: an omitted key means
        // "unchanged" to the backend, which would prevent shrinking a
        // multi-day request back to a single day.
        'endDate': _dateToWire(leave.endDate ?? leave.startDate),
      });
      return _toDomain(updated);
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  // ── Mappers ───────────────────────────────────────────────────────────────

  Leave _toDomain(LeaveDto dto) {
    // The backend always returns an explicit endDate (== startDate for a
    // single-day leave). Collapse that to null so the UI keeps rendering a
    // one-day leave as a single date instead of "12 Apr - 12 Apr".
    final endDate = _sameDay(dto.startDate, dto.endDate) ? null : dto.endDate;
    return Leave(
      id: dto.id,
      category: _categoryFromWire(dto.category),
      startDate: dto.startDate,
      endDate: endDate,
      reason: dto.reason,
      status: _statusFromWire(dto.status),
      createdAt: dto.createdAt,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Wire date format: a bare `yyyy-MM-dd` calendar day. The backend
  /// coerces it and normalizes to the org-TZ start-of-day, so sending a
  /// date-only string avoids any timezone drift a full timestamp could
  /// introduce.
  String _dateToWire(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  LeaveCategory _categoryFromWire(String wire) {
    switch (wire) {
      case 'SICK_LEAVE':
        return LeaveCategory.sick;
      case 'MATERNITY_LEAVE':
        return LeaveCategory.maternity;
      case 'PATERNITY_LEAVE':
        return LeaveCategory.paternity;
      case 'COMPASSIONATE_LEAVE':
        return LeaveCategory.compassionate;
      case 'RELIGIOUS_HOLIDAYS':
        return LeaveCategory.religious;
      case 'FAMILY_RESPONSIBILITY':
        return LeaveCategory.familyResponsibility;
      case 'MISCELLANEOUS':
        return LeaveCategory.others;
      default:
        // Surface unknown categories loudly: silently coercing would
        // misclassify the row and overwrite the backend on the next
        // update. A new backend category crashes here and forces us to
        // extend the enum + mapping.
        throw FormatException('Unsupported leave category: $wire');
    }
  }

  String _categoryToWire(LeaveCategory c) => switch (c) {
    LeaveCategory.sick => 'SICK_LEAVE',
    LeaveCategory.maternity => 'MATERNITY_LEAVE',
    LeaveCategory.paternity => 'PATERNITY_LEAVE',
    LeaveCategory.compassionate => 'COMPASSIONATE_LEAVE',
    LeaveCategory.religious => 'RELIGIOUS_HOLIDAYS',
    LeaveCategory.familyResponsibility => 'FAMILY_RESPONSIBILITY',
    LeaveCategory.others => 'MISCELLANEOUS',
  };

  LeaveStatus _statusFromWire(String wire) {
    switch (wire) {
      case 'PENDING':
        return LeaveStatus.pending;
      case 'APPROVED':
        return LeaveStatus.approved;
      case 'REJECTED':
        return LeaveStatus.rejected;
      default:
        throw FormatException('Unsupported leave status: $wire');
    }
  }

  // ── Error translation ───────────────────────────────────────────────────

  /// Re-throws write failures as the app's [ApiException] hierarchy,
  /// preferring the backend's specific message (overlap conflict, "no
  /// longer pending", etc.) over the interceptor's generic copy — the
  /// interceptor can't reach into our nested `{error:{message}}` envelope.
  Never _throwWriteError(DioException e) {
    final backendMsg = extractBackendErrorMessage(e);
    final mapped = e.error;
    if (mapped is ApiException) {
      if (backendMsg == null || backendMsg == mapped.message) throw mapped;
      // Re-wrap with the backend's specific message while preserving the
      // HTTP semantics the interceptor already classified.
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
          // Auth / location / geofence errors carry their own copy.
          throw mapped;
      }
    }
    throw e;
  }
}

/// Exposes the abstract type so consumers depend on the contract, not the
/// impl class. Tests override this provider with a fake `LeavesRepository`.
final leavesRepositoryProvider = Provider<LeavesRepository>((ref) {
  return LeavesRepositoryImpl(api: ref.watch(leavesApiProvider));
});
