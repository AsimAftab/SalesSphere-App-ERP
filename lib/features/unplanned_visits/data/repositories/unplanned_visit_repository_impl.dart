import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/data/dto/unplanned_visit_dto.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/data/unplanned_visits_api.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/repositories/unplanned_visit_repository.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit_exceptions.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visits_monthly_report.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visits_today.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app. All
/// DTO ↔ domain mapping happens here, plus translation of the backend's
/// structured `409` errors into [UnplannedVisitConflictException].
class UnplannedVisitRepositoryImpl implements UnplannedVisitRepository {
  UnplannedVisitRepositoryImpl({required UnplannedVisitsApi api}) : _api = api;

  final UnplannedVisitsApi _api;

  @override
  Future<UnplannedVisitsToday> getTodayStatus() async {
    final dto = await _api.fetchTodayStatus();
    return UnplannedVisitsToday(
      visits: dto.visits.map(_toDomain).toList(growable: false),
      hasActiveVisit: dto.hasActiveVisit,
      activeVisitId: dto.activeVisitId,
    );
  }

  @override
  Future<UnplannedVisit> getById(String id) async {
    final dto = await _api.fetchById(id);
    return _toDomain(dto);
  }

  @override
  Future<UnplannedVisitsMonthlyReport> getMonthlyReport(
    int year,
    int month,
  ) async {
    // TODO(backend): replace with `GET /unplanned-visits/my-monthly-report`
    // once that endpoint exists. Until then we surface the only history the
    // server can give us — the rep's visits for *today* — so the summary and
    // history UI are real and demoable. Past/future months come back empty.
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;
    final visits = isCurrentMonth
        ? (await getTodayStatus()).visits
        : const <UnplannedVisit>[];
    return UnplannedVisitsMonthlyReport(
      year: year,
      month: month,
      records: visits,
      summary: UnplannedVisitsMonthlySummary.fromVisits(visits),
    );
  }

  @override
  Future<UnplannedVisit> startVisit({
    required VisitTargetType targetType,
    required String targetId,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      final dto = await _api.start(
        targetType: targetType.wire,
        targetId: targetId,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      return _toDomain(dto);
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  @override
  Future<UnplannedVisit> stopVisit({
    required String imagePath,
    String? description,
    DateTime? followUpDate,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      final dto = await _api.stop(
        imagePath: imagePath,
        description: description,
        followUpDate: followUpDate,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      return _toDomain(dto);
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  @override
  Future<void> deleteVisit(String id) async {
    try {
      await _api.delete(id);
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  // ── Error translation ───────────────────────────────────────────────────

  /// Turns a write [DioException] into a typed domain exception using the
  /// backend's structured `error.code`, so the UI can react (toast + refresh)
  /// without parsing strings.
  Never _throwWriteError(DioException e) {
    final body = e.response?.data;
    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        final code = err['code'] as String?;
        final message = err['message'] as String?;
        switch (code) {
          case 'UNPLANNED_VISIT_IN_PROGRESS':
          case 'UNPLANNED_VISIT_NO_ACTIVE':
            throw UnplannedVisitConflictException(
              message ?? 'Your visit status changed. Please refresh.',
              code: code!,
            );
          case 'NOT_CHECKED_IN':
            throw VisitNotCheckedInException(
              message ?? 'You must check in before starting a visit.',
            );
        }
      }
    }
    // The error interceptor stashes a typed [ApiException] in DioException.error
    // (e.g. a generic 422 → ValidationException). Unwrap it so the UI never
    // sees a raw dio error.
    final mapped = e.error;
    if (mapped is ApiException) throw mapped;
    throw e;
  }

  // ── Mappers ───────────────────────────────────────────────────────────────

  UnplannedVisit _toDomain(UnplannedVisitDto dto) => UnplannedVisit(
    id: dto.id,
    status: _statusFromWire(dto.status),
    target: _targetToDomain(dto.target),
    startedAt: dto.startTime,
    startLocation: _toLocation(dto.startLocation),
    stoppedAt: dto.stopTime,
    stopLocation: _toLocation(dto.stopLocation),
    imageUrl: dto.image,
    description: dto.description,
    followUpDate: dto.followUpDate,
    durationSeconds: dto.durationSeconds,
    createdAt: dto.createdAt,
    updatedAt: dto.updatedAt,
  );

  VisitTarget _targetToDomain(VisitTargetDto dto) => VisitTarget(
    type: _targetTypeFromWire(dto.type),
    id: dto.id,
    displayName: dto.name,
    address: dto.address,
    latitude: dto.latitude,
    longitude: dto.longitude,
  );

  VisitLocation? _toLocation(VisitLocationDto? dto) => dto == null
      ? null
      : VisitLocation(
          latitude: dto.latitude,
          longitude: dto.longitude,
          address: dto.address,
        );

  VisitStatus _statusFromWire(String wire) {
    switch (wire) {
      case 'in_progress':
        return VisitStatus.inProgress;
      case 'completed':
        return VisitStatus.completed;
      default:
        throw FormatException('Unsupported VisitStatus wire: $wire');
    }
  }

  VisitTargetType _targetTypeFromWire(String wire) {
    switch (wire) {
      case 'customer':
        return VisitTargetType.customer;
      case 'prospect':
        return VisitTargetType.prospect;
      case 'site':
        return VisitTargetType.site;
      default:
        throw FormatException('Unsupported VisitTargetType wire: $wire');
    }
  }
}

/// Exposes the abstract type so consumers depend on the contract, not the impl
/// class. Tests override this provider with a fake `UnplannedVisitRepository`.
final unplannedVisitRepositoryProvider = Provider<UnplannedVisitRepository>(
  (ref) => UnplannedVisitRepositoryImpl(api: ref.watch(unplannedVisitsApiProvider)),
);
