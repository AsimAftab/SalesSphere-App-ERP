import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/attendance/data/attendance_api.dart';
import 'package:sales_sphere_erp/features/attendance/data/dto/attendance_record_dto.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_today_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/geofence_config.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_report.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_summary.dart';
import 'package:sales_sphere_erp/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:sales_sphere_erp/features/attendance/domain/work_schedule.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO ↔ domain mapping happens here. Drift persistence + outbox enqueue
/// will land alongside an offline pass (tracked as follow-up).
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
      schedule: _scheduleFromWire(dto),
      geofence: GeofenceConfig(
        enabled: dto.orgEnableGeoFencingAttendance,
        latitude: dto.orgLatitude,
        longitude: dto.orgLongitude,
        address: dto.orgAddress,
        googleMapLink: dto.orgGoogleMapLink,
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
      // The error interceptor stashes a typed [ApiException] in
      // DioException.error (a 400 becomes a ValidationException carrying the
      // backend's window/weekly-off message). Unwrap so the UI never sees a
      // raw dio error and the message surfaces via userMessageFor.
      final mapped = e.error;
      if (mapped is ApiException) throw mapped;
      rethrow;
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
      final mapped = e.error;
      if (mapped is ApiException) throw mapped;
      rethrow;
    }
  }

  // ── Mappers ───────────────────────────────────────────────────────────────

  /// Builds the [WorkSchedule] from the org's shift times. When any of the
  /// three times is missing/unparseable, [WorkSchedule.enforceWindows] is set
  /// false so the app doesn't gate by window (the server stays the authority);
  /// weekly-off days still apply. The fallback times are placeholders only —
  /// they aren't consulted while `enforceWindows` is false.
  WorkSchedule _scheduleFromWire(AttendanceTodayStatusDto dto) {
    final checkIn = _parseHHmm(dto.orgCheckInTime);
    final checkOut = _parseHHmm(dto.orgCheckOutTime);
    final halfDay = _parseHHmm(dto.orgHalfDayCheckOutTime);
    final enforce = checkIn != null && checkOut != null && halfDay != null;
    return WorkSchedule(
      scheduledCheckIn: checkIn ?? const TimeOfDay(hour: 9, minute: 0),
      scheduledCheckOut: checkOut ?? const TimeOfDay(hour: 18, minute: 0),
      scheduledHalfDayCheckOut: halfDay ?? const TimeOfDay(hour: 13, minute: 0),
      weeklyOffDays:
          dto.orgWeeklyOffDays.map(_weekdayToIso).whereType<int>().toSet(),
      enforceWindows: enforce,
    );
  }

  /// Parses an `HH:MM` (or short `HH`) 24-hour string into a [TimeOfDay].
  /// Tolerates the malformed shapes the backend can send (e.g. `"22"` →
  /// 22:00, `"21:00"`, `null`, `""`); returns null when unparseable.
  TimeOfDay? _parseHHmm(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final parts = trimmed.split(':');
    final hour = int.tryParse(parts[0]);
    if (hour == null || hour < 0 || hour > 23) return null;
    var minute = 0;
    if (parts.length > 1) {
      final m = int.tryParse(parts[1]);
      if (m == null || m < 0 || m > 59) return null;
      minute = m;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Maps a backend weekday name (`SUNDAY`…`SATURDAY`) to an ISO weekday int
  /// (Mon = 1 … Sun = 7), matching [DateTime.weekday] and
  /// [WorkSchedule.weeklyOffDays].
  int? _weekdayToIso(String name) {
    switch (name.toUpperCase()) {
      case 'MONDAY':
        return DateTime.monday;
      case 'TUESDAY':
        return DateTime.tuesday;
      case 'WEDNESDAY':
        return DateTime.wednesday;
      case 'THURSDAY':
        return DateTime.thursday;
      case 'FRIDAY':
        return DateTime.friday;
      case 'SATURDAY':
        return DateTime.saturday;
      case 'SUNDAY':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  /// Maps the server's status tally into the UI summary. The `LATE` count
  /// overlaps `PRESENT`, so it's surfaced separately rather than folded into
  /// the working-day maths. Attendance % isn't sent by the backend, so it's
  /// derived here (half-day = 0.5; weekly-offs excluded from the denominator).
  MonthlySummary _summaryFromWire(Map<String, int> tally) {
    final present = tally['PRESENT'] ?? 0;
    final absent = tally['ABSENT'] ?? 0;
    final leave = tally['LEAVE'] ?? 0;
    final halfDay = tally['HALF_DAY'] ?? 0;
    final weeklyOff = tally['WEEKLY_OFF'] ?? 0;
    final late = tally['LATE'] ?? 0;

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
      late: late,
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
        isLate: dto.isLate,
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
