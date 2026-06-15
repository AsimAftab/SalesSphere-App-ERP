import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/attendance/data/attendance_api.dart';
import 'package:sales_sphere_erp/features/attendance/data/dto/attendance_record_dto.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_report.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_summary.dart';
import 'package:sales_sphere_erp/features/attendance/domain/repositories/attendance_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the
/// app. All DTO ↔ domain mapping happens here. Drift persistence +
/// outbox enqueue will land alongside the real API.
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

  /// Maps the server's status tally into the UI summary. The `LATE`
  /// count overlaps `PRESENT`, so it's surfaced separately rather than
  /// folded into the working-day maths. Attendance % isn't sent by the
  /// backend, so it's derived here (half-day = 0.5; weekly-offs are
  /// excluded from the denominator) to match the prior behaviour.
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

  @override
  Future<AttendanceRecord> checkIn({
    required DateTime at,
    required String userId,
    required String userName,
    required String userRole,
    double? lat,
    double? lng,
    String? address,
  }) async {
    final dto = await _api.upsertCheckIn(
      at: at,
      userId: userId,
      userName: userName,
      userRole: userRole,
      lat: lat,
      lng: lng,
      address: address,
    );
    return _toDomain(dto);
  }

  @override
  Future<AttendanceRecord> checkOut({
    required DateTime at,
    double? lat,
    double? lng,
    String? address,
  }) async {
    final dto = await _api.upsertCheckOut(
      at: at,
      lat: lat,
      lng: lng,
      address: address,
    );
    return _toDomain(dto);
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
        // Surface unknown statuses loudly: silently coercing to
        // `present` would misclassify the row in the UI and — worse —
        // overwrite the backend with `'present'` on the next update.
        // If/when the backend grows a sixth status, this will crash
        // and force us to extend the enum + mapping rather than rotting
        // unnoticed.
        throw FormatException('Unsupported AttendanceStatus wire: $wire');
    }
  }
}

/// Exposes the abstract type so consumers depend on the contract,
/// not the impl class. Tests override this provider with a fake
/// `AttendanceRepository`.
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(api: ref.watch(attendanceApiProvider));
});
