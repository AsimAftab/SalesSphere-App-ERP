import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/attendance/data/attendance_api.dart';
import 'package:sales_sphere_erp/features/attendance/data/dto/attendance_record_dto.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_exceptions.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_today_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/geofence_config.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_report.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_summary.dart';
import 'package:sales_sphere_erp/features/attendance/domain/repositories/attendance_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO ↔ domain mapping happens here, plus translation of the backend's
/// structured attendance errors into typed domain exceptions.
class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({required AttendanceApi api}) : _api = api;

  final AttendanceApi _api;

  @override
  Future<MonthlyReport> getMonthlyReport(int year, int month) async {
    final dto = await _api.fetchMonthlyReport(year, month);
    final records = dto.records.map(_toDomain).toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));
    return MonthlyReport(
      records: records,
      summary: _summaryFromWire(dto.summary),
    );
  }

  @override
  Future<AttendanceTodayStatus> getTodayStatus() async {
    final dto = await _api.fetchTodayStatus();
    return AttendanceTodayStatus(
      record: dto.record == null ? null : _toDomain(dto.record!),
      geofence: GeofenceConfig(
        enabled: dto.geofenceEnabled,
        latitude: dto.geofenceLatitude,
        longitude: dto.geofenceLongitude,
        address: dto.geofenceAddress,
        googleMapLink: dto.geofenceGoogleMapLink,
      ),
    );
  }

  @override
  Future<AttendanceRecord> checkIn({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      final dto = await _api.checkIn(
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
  Future<AttendanceRecord> checkOut({
    required double latitude,
    required double longitude,
    required String address,
    required bool isHalfDay,
  }) async {
    try {
      final dto = await _api.checkOut(
        latitude: latitude,
        longitude: longitude,
        address: address,
        isHalfDay: isHalfDay,
      );
      return _toDomain(dto);
    } on DioException catch (e) {
      _throwWriteError(e);
    }
  }

  // ── Error translation ───────────────────────────────────────────────────

  /// Turns a check-in/out [DioException] into a typed domain exception using
  /// the backend's structured `error.code` + `error.details`, so the UI can
  /// react (half-day fallback, refresh on conflict) without parsing strings.
  Never _throwWriteError(DioException e) {
    final body = e.response?.data;
    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        final code = err['code'] as String?;
        final message = err['message'] as String?;
        final raw = err['details'];
        final details = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
        switch (code) {
          case 'ATTENDANCE_CHECKIN_RESTRICTED':
            throw CheckInRestrictionException.fromDetails(message, details);
          case 'ATTENDANCE_CHECKOUT_RESTRICTED':
            throw CheckOutRestrictionException.fromDetails(message, details);
          case 'ATTENDANCE_ALREADY_CHECKED_IN':
          case 'ATTENDANCE_ALREADY_CHECKED_OUT':
          case 'ATTENDANCE_NOT_CHECKED_IN':
            throw AttendanceConflictException(
              message ?? 'Your attendance was already updated.',
              code: code!,
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

  /// Maps the server's status tally into the UI summary. Attendance % isn't
  /// sent by the backend, so it's derived here (half-day = 0.5; weekly-offs
  /// excluded).
  MonthlySummary _summaryFromWire(Map<String, int> tally) {
    final present = tally['PRESENT'] ?? 0;
    final absent = tally['ABSENT'] ?? 0;
    final leave = tally['LEAVE'] ?? 0;
    final halfDay = tally['HALF_DAY'] ?? 0;
    final weeklyOff = tally['WEEKLY_OFF'] ?? 0;

    final workingDays = present + absent + leave + halfDay;
    final attendancePct = workingDays == 0
        ? 0.0
        : ((present + halfDay * 0.5) / workingDays) * 100;

    return MonthlySummary(
      present: present,
      absent: absent,
      leave: leave,
      halfDay: halfDay,
      weeklyOff: weeklyOff,
      attendancePct: attendancePct,
    );
  }

  AttendanceRecord _toDomain(AttendanceRecordDto dto) => AttendanceRecord(
        id: dto.id,
        date: dto.date,
        status: _statusFromWire(dto.status),
        checkInAt: dto.checkInAt,
        checkOutAt: dto.checkOutAt,
        checkInLat: dto.checkInLat,
        checkInLng: dto.checkInLng,
        checkInAddress: dto.checkInAddress,
        checkOutLat: dto.checkOutLat,
        checkOutLng: dto.checkOutLng,
        checkOutAddress: dto.checkOutAddress,
        markedByUserId: dto.markedByUserId,
        markedByName: dto.markedByName,
        markedByRole: dto.markedByRole,
      );

  AttendanceStatus _statusFromWire(String wire) {
    switch (wire) {
      case 'PRESENT':
        return AttendanceStatus.present;
      case 'ABSENT':
        return AttendanceStatus.absent;
      case 'LEAVE':
        return AttendanceStatus.leave;
      case 'HALF_DAY':
        return AttendanceStatus.halfDay;
      case 'WEEKLY_OFF':
        return AttendanceStatus.weeklyOff;
      default:
        // Surface unknown statuses loudly rather than misclassifying the row.
        throw FormatException('Unsupported AttendanceStatus wire: $wire');
    }
  }
}

/// Exposes the abstract type so consumers depend on the contract, not the
/// impl class. Tests override this provider with a fake `AttendanceRepository`.
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(api: ref.watch(attendanceApiProvider));
});
