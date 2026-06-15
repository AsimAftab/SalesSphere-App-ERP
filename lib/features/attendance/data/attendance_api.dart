import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/attendance/data/dto/attendance_record_dto.dart';

/// Raw data source for the attendance endpoints. The monthly report
/// (which drives the calendar + summary) hits the live backend over
/// [_dio]; check-in / check-out are still backed by a mutable in-memory
/// map keyed by `YYYY-MM-DD` until those endpoints are wired. Repository
/// callers stay unchanged.
class AttendanceApi {
  AttendanceApi(this._dio) {
    _seedCurrentMonth();
  }

  final Dio _dio;

  /// `'YYYY-MM-DD' → DTO`. Day key, not timestamp, because each calendar
  /// day has at most one row and dispatches on date-only equality.
  final Map<String, AttendanceRecordDto> _store =
      <String, AttendanceRecordDto>{};

  /// Seeds a deterministic mix of statuses for every day **before**
  /// today in the current month. Today itself is intentionally left
  /// blank so the home page lands on the "Not Checked In" state and
  /// the user can click Check In → Check Out → Checked Out naturally
  /// without the seed pre-populating the row.
  void _seedCurrentMonth() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upto = today.day - 1;
    for (var day = 1; day <= upto; day++) {
      final date = DateTime(now.year, now.month, day);
      final status = _seededStatus(date);
      // Only present/half-day rows seed timestamps + location; leave
      // and absent are paperwork-only so the row carries no times.
      final hasTimes = status == 'PRESENT' || status == 'HALF_DAY';
      _store[_dayKey(date)] = AttendanceRecordDto(
        id: 'seed-${date.toIso8601String()}',
        date: date,
        status: status,
        checkInAt: hasTimes
            ? DateTime(date.year, date.month, date.day, 9, 10 + (day % 20))
            : null,
        checkOutAt: hasTimes
            ? DateTime(
                date.year,
                date.month,
                date.day,
                status == 'HALF_DAY' ? 13 : 18,
                15 + (day % 30),
              )
            : null,
        checkInLat: hasTimes ? 12.9716 + (day % 7) * 0.005 : null,
        checkInLng: hasTimes ? 77.5946 + (day % 7) * 0.005 : null,
        checkInAddress: hasTimes
            ? 'Plot $day, MG Road, Bengaluru, Karnataka 560001, India'
            : null,
        checkOutLat: hasTimes ? 12.9716 + (day % 7) * 0.005 : null,
        checkOutLng: hasTimes ? 77.5946 + (day % 7) * 0.005 : null,
        checkOutAddress: hasTimes
            ? 'Plot $day, MG Road, Bengaluru, Karnataka 560001, India'
            : null,
        markedByUserId: 'seed-user',
        markedByName: 'Vikram Sharma',
        markedByRole: 'Field Executive',
      );
    }
  }

  String _seededStatus(DateTime date) {
    if (date.weekday == DateTime.sunday) return 'WEEKLY_OFF';
    final d = date.day;
    if (d % 7 == 3) return 'ABSENT';
    if (d % 11 == 0) return 'LEAVE';
    if (d % 5 == 0) return 'HALF_DAY';
    return 'PRESENT';
  }

  /// `GET /attendance/my-monthly-report?year=&month=` — the signed-in
  /// rep's attendance for the month: per-day rows plus a server-computed
  /// status tally. Powers the calendar and the monthly summary card.
  Future<MonthlyReportDto> fetchMonthlyReport(int year, int month) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.attendanceMyMonthlyReport,
      queryParameters: <String, dynamic>{'year': year, 'month': month},
    );
    return MonthlyReportDto.fromJson(_unwrap(response.data));
  }

  /// Peels the outer `{success, data}` transport envelope and returns
  /// the inner report object (`{success, summary, data}`).
  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty attendance response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Attendance API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed attendance envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }

  Future<AttendanceRecordDto?> getForDate(DateTime date) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final dto = _store[_dayKey(date)];
    return dto == null ? null : _cloneDto(dto);
  }

  Future<AttendanceRecordDto> upsertCheckIn({
    required DateTime at,
    required String userId,
    required String userName,
    required String userRole,
    double? lat,
    double? lng,
    String? address,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final day = DateTime(at.year, at.month, at.day);
    final created = AttendanceRecordDto(
      id: 'live-${at.microsecondsSinceEpoch}',
      date: day,
      status: 'PRESENT',
      checkInAt: at,
      checkInLat: lat,
      checkInLng: lng,
      checkInAddress: address,
      markedByUserId: userId,
      markedByName: userName,
      markedByRole: userRole,
    );
    _store[_dayKey(day)] = created;
    return _cloneDto(created);
  }

  Future<AttendanceRecordDto> upsertCheckOut({
    required DateTime at,
    double? lat,
    double? lng,
    String? address,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final key = _dayKey(DateTime(at.year, at.month, at.day));
    final existing = _store[key];
    if (existing == null) {
      throw StateError('No check-in for ${at.toIso8601String()}');
    }
    final updated = AttendanceRecordDto(
      id: existing.id,
      date: existing.date,
      status: existing.status,
      checkInAt: existing.checkInAt,
      checkOutAt: at,
      checkInLat: existing.checkInLat,
      checkInLng: existing.checkInLng,
      checkInAddress: existing.checkInAddress,
      checkOutLat: lat,
      checkOutLng: lng,
      checkOutAddress: address,
      markedByUserId: existing.markedByUserId,
      markedByName: existing.markedByName,
      markedByRole: existing.markedByRole,
    );
    _store[key] = updated;
    return _cloneDto(updated);
  }

  /// `YYYY-MM-DD` key. The DTO's own `date` field is the source of
  /// truth for renders; this map key only exists for O(1) by-day
  /// lookup.
  String _dayKey(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Defensive copy so callers can't reach back into the store and
  /// mutate a seeded row (mirrors NotesApi._cloneDto).
  AttendanceRecordDto _cloneDto(AttendanceRecordDto dto) => AttendanceRecordDto(
        id: dto.id,
        date: dto.date,
        status: dto.status,
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
}

final attendanceApiProvider = Provider<AttendanceApi>(
  (ref) => AttendanceApi(ref.watch(dioProvider)),
);
