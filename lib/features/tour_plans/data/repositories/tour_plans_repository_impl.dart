import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/tour_plans/data/dto/tour_plan_dto.dart';
import 'package:sales_sphere_erp/features/tour_plans/data/tour_plans_api.dart';
import 'package:sales_sphere_erp/features/tour_plans/domain/repositories/tour_plans_repository.dart';
import 'package:sales_sphere_erp/features/tour_plans/domain/tour_plan.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the
/// app. All DTO ↔ domain mapping happens here. Drift persistence +
/// outbox enqueue will land alongside the real API.
class TourPlansRepositoryImpl implements TourPlansRepository {
  TourPlansRepositoryImpl({required TourPlansApi api}) : _api = api;

  final TourPlansApi _api;

  @override
  Future<List<TourPlan>> getTourPlans({
    TourPlanStatus? status,
    int limit = 10,
  }) async {
    final dtos = await _api.list(
      status: status == null ? null : _statusToWire(status),
      limit: limit,
    );
    return dtos.map(_toDomain).toList(growable: false);
  }

  @override
  Future<TourPlan?> getTourPlanById(String id) async {
    final dto = await _api.getById(id);
    return dto == null ? null : _toDomain(dto);
  }

  @override
  Future<TourPlan> addTourPlan(TourPlan draft) async {
    final created = await _api.create(_toDto(draft));
    return _toDomain(created);
  }

  @override
  Future<TourPlan> updateTourPlan(TourPlan plan) async {
    final updated = await _api.update(_toDto(plan));
    return _toDomain(updated);
  }

  @override
  Future<TourPlan> markTourPlanCompleted(String id) async {
    final updated = await _api.markTourPlanCompleted(id);
    return _toDomain(updated);
  }

  TourPlan _toDomain(TourPlanDto dto) => TourPlan(
    id: dto.id,
    placeOfVisit: dto.placeOfVisit,
    startDate: dto.startDate,
    endDate: dto.endDate,
    purpose: dto.purpose,
    status: _statusFromWire(dto.status),
    createdAt: dto.createdAt,
    rejectionReason: dto.rejectionReason,
  );

  TourPlanDto _toDto(TourPlan p) => TourPlanDto(
    // Server assigns the canonical id on create — placeholder here.
    id: p.id,
    placeOfVisit: p.placeOfVisit,
    startDate: p.startDate,
    endDate: p.endDate,
    purpose: p.purpose,
    status: _statusToWire(p.status),
    createdAt: p.createdAt,
    rejectionReason: p.rejectionReason,
  );

  TourPlanStatus _statusFromWire(String wire) {
    switch (wire.toLowerCase()) {
      case 'pending':
        return TourPlanStatus.pending;
      case 'approved':
        return TourPlanStatus.approved;
      case 'rejected':
        return TourPlanStatus.rejected;
      case 'completed':
        return TourPlanStatus.completed;
      default:
        throw FormatException('Unsupported tour-plan status: $wire');
    }
  }

  String _statusToWire(TourPlanStatus s) => switch (s) {
    TourPlanStatus.pending => 'PENDING',
    TourPlanStatus.approved => 'APPROVED',
    TourPlanStatus.rejected => 'REJECTED',
    TourPlanStatus.completed => 'COMPLETED',
  };
}

/// Exposes the abstract type so consumers depend on the contract, not
/// the impl class. Tests override this provider with a fake
/// `TourPlansRepository`.
final tourPlansRepositoryProvider = Provider<TourPlansRepository>((ref) {
  return TourPlansRepositoryImpl(api: ref.watch(tourPlansApiProvider));
});
