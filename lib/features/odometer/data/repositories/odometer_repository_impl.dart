import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/odometer/data/dto/odometer_monthly_report_dto.dart';
import 'package:sales_sphere_erp/features/odometer/data/dto/odometer_record_dto.dart';
import 'package:sales_sphere_erp/features/odometer/data/odometer_api.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_exceptions.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_monthly_report.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_today_status.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/domain/repositories/odometer_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app. All
/// DTO ↔ domain mapping happens here, plus translation of the backend's
/// structured `409` errors into [OdometerConflictException].
class OdometerRepositoryImpl implements OdometerRepository {
  OdometerRepositoryImpl({required OdometerApi api}) : _api = api;

  final OdometerApi _api;

  @override
  Future<OdometerTodayStatus> getTodayStatus() async {
    final dto = await _api.fetchTodayStatus();
    final trips = dto.trips.map(_toDomain).toList(growable: false)
      ..sort((a, b) => a.tripNumber.compareTo(b.tripNumber));
    return OdometerTodayStatus(
      trips: trips,
      hasActiveTrip: dto.hasActiveTrip,
      activeTripId: dto.activeTripId,
    );
  }

  @override
  Future<OdometerMonthlyReport> getMonthlyReport(int year, int month) async {
    final dto = await _api.fetchMonthlyReport(year, month);
    final records = dto.records.map(_toDomain).toList(growable: false)
      ..sort((a, b) {
        final byDate =
            (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0));
        return byDate != 0 ? byDate : a.tripNumber.compareTo(b.tripNumber);
      });
    return OdometerMonthlyReport(
      month: dto.month,
      year: dto.year,
      records: records,
      summary: _summaryToDomain(dto.summary),
    );
  }

  @override
  Future<OdometerTrip> getTripById(String id) async {
    final dto = await _api.fetchById(id);
    return _toDomain(dto);
  }

  @override
  Future<OdometerTrip> startTrip({
    required double startReading,
    required DistanceUnit unit,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? imagePath,
  }) async {
    try {
      final dto = await _api.start(
        startReading: startReading,
        unit: unit.name,
        description: description,
        latitude: latitude,
        longitude: longitude,
        address: address,
        imagePath: imagePath,
      );
      return _toDomain(dto);
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  @override
  Future<OdometerTrip> stopTrip({
    required double stopReading,
    required DistanceUnit unit,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? imagePath,
  }) async {
    try {
      final dto = await _api.stop(
        stopReading: stopReading,
        unit: unit.name,
        description: description,
        latitude: latitude,
        longitude: longitude,
        address: address,
        imagePath: imagePath,
      );
      return _toDomain(dto);
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  @override
  Future<void> deleteTrip(String id) async {
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
          case 'ODOMETER_TRIP_IN_PROGRESS':
          case 'ODOMETER_NO_ACTIVE_TRIP':
            throw OdometerConflictException(
              message ?? 'Your odometer status changed. Please refresh.',
              code: code!,
            );
          case 'NOT_CHECKED_IN':
            throw OdometerNotCheckedInException(
              message ?? 'You must check in before starting a trip.',
            );
          // 502 from the backend's media store — transient; the sheet stays
          // open so the rep can retry with the same photo.
          case 'UPLOAD_FAILED':
            throw const UploadFailedException();
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

  OdometerMonthlySummary _summaryToDomain(OdometerMonthlySummaryDto dto) =>
      OdometerMonthlySummary(
        totalDistance: dto.totalDistance,
        distanceUnit: dto.distanceUnit,
        totalTrips: dto.totalTrips,
        tripsCompleted: dto.tripsCompleted,
        tripsInProgress: dto.tripsInProgress,
        avgDistancePerTrip: dto.avgDistancePerTrip,
      );

  OdometerTrip _toDomain(OdometerRecordDto dto) => OdometerTrip(
        id: dto.id,
        employeeId: dto.employeeId,
        date: dto.date,
        tripNumber: dto.tripNumber,
        status: _statusFromWire(dto.status),
        distanceUnit: _unitFromWire(dto.startUnit ?? dto.stopUnit),
        startReading: dto.startReading,
        startImageUrl: dto.startImage,
        startDescription: dto.startDescription,
        startedAt: dto.startTime,
        startLocation: _toLocation(dto.startLocation),
        stopReading: dto.stopReading,
        stopImageUrl: dto.stopImage,
        stopDescription: dto.stopDescription,
        stoppedAt: dto.stopTime,
        stopLocation: _toLocation(dto.stopLocation),
        distance: dto.distance,
        createdAt: dto.createdAt,
        updatedAt: dto.updatedAt,
      );

  TripLocation? _toLocation(TripLocationDto? dto) => dto == null
      ? null
      : TripLocation(
          latitude: dto.latitude,
          longitude: dto.longitude,
          address: dto.address,
        );

  OdometerStatus _statusFromWire(String wire) {
    switch (wire) {
      case 'not_started':
        return OdometerStatus.notStarted;
      case 'in_progress':
        return OdometerStatus.inProgress;
      case 'completed':
        return OdometerStatus.completed;
      default:
        throw FormatException('Unsupported OdometerStatus wire: $wire');
    }
  }

  /// Maps the lowercase wire unit. Defaults to km when absent (e.g. a trip
  /// that hasn't recorded a leg yet); throws on an unknown non-null value.
  DistanceUnit _unitFromWire(String? wire) {
    switch (wire) {
      case null:
      case 'km':
        return DistanceUnit.km;
      case 'miles':
        return DistanceUnit.miles;
      default:
        throw FormatException('Unsupported DistanceUnit wire: $wire');
    }
  }
}

/// Exposes the abstract type so consumers depend on the contract, not the impl
/// class. Tests override this provider with a fake `OdometerRepository`.
final odometerRepositoryProvider = Provider<OdometerRepository>((ref) {
  return OdometerRepositoryImpl(api: ref.watch(odometerApiProvider));
});
