import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/attendance/data/dto/attendance_record_dto.dart';

/// HTTP layer for attendance. Every call hits the live backend; the
/// `{success, data}` transport envelope is peeled by [_unwrap]. Check-in
/// (POST) and check-out (PUT) wrap the row a level deeper under `data.record`
/// (see [_record]).
class AttendanceApi {
  AttendanceApi(this._dio);

  final Dio _dio;

  /// `GET /attendance/my-monthly-report?year=&month=` — the signed-in rep's
  /// attendance for the month: per-day rows plus a server-computed status
  /// tally. Powers the calendar and the monthly summary card.
  Future<MonthlyReportDto> fetchMonthlyReport(int year, int month) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.attendanceMyMonthlyReport,
      queryParameters: <String, dynamic>{'year': year, 'month': month},
    );
    return MonthlyReportDto.fromJson(_unwrap(response.data));
  }

  /// `GET /attendance/status/today` — today's record (or null) plus the org
  /// schedule + geofence configuration.
  Future<AttendanceTodayStatusDto> fetchTodayStatus() async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.attendanceStatusToday,
    );
    return AttendanceTodayStatusDto.fromJson(_unwrap(response.data));
  }

  /// `POST /attendance/check-in` — body `{latitude, longitude, address}`.
  /// The server stamps the time and resolves identity from the session.
  Future<AttendanceRecordDto> checkIn({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.attendanceCheckIn,
      data: <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      },
    );
    return AttendanceRecordDto.fromJson(_record(response.data));
  }

  /// `PUT /attendance/check-out` — body `{latitude, longitude, address,
  /// isHalfDay}`.
  Future<AttendanceRecordDto> checkOut({
    required double latitude,
    required double longitude,
    required String address,
    required bool isHalfDay,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      Endpoints.attendanceCheckOut,
      data: <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'isHalfDay': isHalfDay,
      },
    );
    return AttendanceRecordDto.fromJson(_record(response.data));
  }

  /// Peels the outer `{success, data}` transport envelope and returns the
  /// inner object.
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

  /// Check-in/out nest the attendance row under `data.record`; unwrap both
  /// layers and return the record map.
  Map<String, dynamic> _record(Map<String, dynamic>? body) {
    final data = _unwrap(body);
    final record = data['record'];
    if (record is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed attendance response: missing or invalid `record` object',
      );
    }
    return record;
  }
}

final attendanceApiProvider = Provider<AttendanceApi>(
  (ref) => AttendanceApi(ref.watch(dioProvider)),
);
