import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/leaves/data/dto/leave_dto.dart';
import 'package:sales_sphere_erp/features/leaves/data/leaves_api.dart';
import 'package:sales_sphere_erp/features/leaves/domain/leave.dart';
import 'package:sales_sphere_erp/features/leaves/domain/repositories/leaves_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the
/// app. All DTO ↔ domain mapping happens here. Drift persistence +
/// outbox enqueue will land alongside the real API.
class LeavesRepositoryImpl implements LeavesRepository {
  LeavesRepositoryImpl({required LeavesApi api}) : _api = api;

  final LeavesApi _api;

  @override
  Future<List<Leave>> getLeaves() async {
    final dtos = await _api.list();
    return dtos.map(_toDomain).toList(growable: false);
  }

  @override
  Future<Leave> addLeave(Leave draft) async {
    final created = await _api.create(_toDto(draft));
    return _toDomain(created);
  }

  @override
  Future<Leave> updateLeave(Leave leave) async {
    final updated = await _api.update(_toDto(leave));
    return _toDomain(updated);
  }

  Leave _toDomain(LeaveDto dto) => Leave(
    id: dto.id,
    category: _categoryFromWire(dto.category),
    startDate: dto.startDate,
    endDate: dto.endDate,
    reason: dto.reason,
    status: _statusFromWire(dto.status),
    createdAt: dto.createdAt,
  );

  LeaveDto _toDto(Leave l) => LeaveDto(
    // Server assigns the canonical id on create — placeholder here.
    id: l.id,
    category: _categoryToWire(l.category),
    startDate: l.startDate,
    endDate: l.endDate,
    reason: l.reason,
    status: _statusToWire(l.status),
    createdAt: l.createdAt,
  );

  LeaveCategory _categoryFromWire(String wire) {
    switch (wire) {
      case 'sick':
        return LeaveCategory.sick;
      case 'maternity':
        return LeaveCategory.maternity;
      case 'paternity':
        return LeaveCategory.paternity;
      case 'compassionate':
        return LeaveCategory.compassionate;
      case 'religious':
        return LeaveCategory.religious;
      case 'familyResponsibility':
        return LeaveCategory.familyResponsibility;
      case 'others':
        return LeaveCategory.others;
      default:
        // Surface unknown categories loudly: silently coercing would
        // misclassify the row and overwrite the backend on the next
        // update. If/when the backend grows a new category, this
        // crashes and forces us to extend the enum + mapping.
        throw FormatException('Unsupported leave category: $wire');
    }
  }

  String _categoryToWire(LeaveCategory c) => switch (c) {
    LeaveCategory.sick => 'sick',
    LeaveCategory.maternity => 'maternity',
    LeaveCategory.paternity => 'paternity',
    LeaveCategory.compassionate => 'compassionate',
    LeaveCategory.religious => 'religious',
    LeaveCategory.familyResponsibility => 'familyResponsibility',
    LeaveCategory.others => 'others',
  };

  LeaveStatus _statusFromWire(String wire) {
    switch (wire) {
      case 'pending':
        return LeaveStatus.pending;
      case 'approved':
        return LeaveStatus.approved;
      case 'rejected':
        return LeaveStatus.rejected;
      default:
        throw FormatException('Unsupported leave status: $wire');
    }
  }

  String _statusToWire(LeaveStatus s) => switch (s) {
    LeaveStatus.pending => 'pending',
    LeaveStatus.approved => 'approved',
    LeaveStatus.rejected => 'rejected',
  };
}

/// Exposes the abstract type so consumers depend on the contract, not
/// the impl class. Tests override this provider with a fake
/// `LeavesRepository`.
final leavesRepositoryProvider = Provider<LeavesRepository>((ref) {
  return LeavesRepositoryImpl(api: ref.watch(leavesApiProvider));
});
