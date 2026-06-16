import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/attendance/data/attendance_api.dart';
import 'package:sales_sphere_erp/features/attendance/data/dto/attendance_record_dto.dart';
import 'package:sales_sphere_erp/features/attendance/data/repositories/attendance_repository_impl.dart';

/// Fakes the HTTP layer so we can drive [AttendanceRepositoryImpl.getTodayStatus]
/// with hand-built DTOs and assert the schedule/geofence mapping. Only
/// `fetchTodayStatus` is exercised.
class _FakeApi implements AttendanceApi {
  _FakeApi(this.status);

  AttendanceTodayStatusDto status;

  @override
  Future<AttendanceTodayStatusDto> fetchTodayStatus() async => status;

  @override
  Future<MonthlyReportDto> fetchMonthlyReport(int year, int month) =>
      throw UnimplementedError();

  @override
  Future<AttendanceRecordDto> checkIn({
    required double latitude,
    required double longitude,
    required String address,
  }) =>
      throw UnimplementedError();

  @override
  Future<AttendanceRecordDto> checkOut({
    required double latitude,
    required double longitude,
    required String address,
    required bool isHalfDay,
  }) =>
      throw UnimplementedError();
}

AttendanceTodayStatusDto statusDto({
  String? checkIn = '22',
  String? checkOut = '21:00',
  String? halfDay = '14:00',
  bool geofenceEnabled = true,
}) {
  return AttendanceTodayStatusDto(
    record: null,
    timezone: 'Asia/Kathmandu',
    orgCheckInTime: checkIn,
    orgCheckOutTime: checkOut,
    orgHalfDayCheckOutTime: halfDay,
    orgWeeklyOffDays: const <String>['SATURDAY'],
    orgEnableGeoFencingAttendance: geofenceEnabled,
    orgLatitude: 27.6766,
    orgLongitude: 85.316,
    orgAddress: 'Lalitpur',
    orgGoogleMapLink: null,
  );
}

void main() {
  group('getTodayStatus → schedule mapping', () {
    test('parses HH and HH:MM times (incl. malformed "22" → 22:00)', () async {
      final repo = AttendanceRepositoryImpl(api: _FakeApi(statusDto()));
      final status = await repo.getTodayStatus();

      expect(status.schedule.scheduledCheckIn, const TimeOfDay(hour: 22, minute: 0));
      expect(status.schedule.scheduledCheckOut, const TimeOfDay(hour: 21, minute: 0));
      expect(
        status.schedule.scheduledHalfDayCheckOut,
        const TimeOfDay(hour: 14, minute: 0),
      );
      expect(status.schedule.enforceWindows, isTrue);
    });

    test('maps SATURDAY → ISO weekday 6', () async {
      final repo = AttendanceRepositoryImpl(api: _FakeApi(statusDto()));
      final status = await repo.getTodayStatus();
      expect(status.schedule.weeklyOffDays, <int>{DateTime.saturday});
    });

    test('enforceWindows is false when any org time is missing', () async {
      final repo =
          AttendanceRepositoryImpl(api: _FakeApi(statusDto(checkIn: null)));
      final status = await repo.getTodayStatus();
      expect(status.schedule.enforceWindows, isFalse);
    });
  });

  group('getTodayStatus → geofence mapping', () {
    test('active when enabled with an anchor', () async {
      final repo = AttendanceRepositoryImpl(api: _FakeApi(statusDto()));
      final status = await repo.getTodayStatus();
      expect(status.geofence.isActive, isTrue);
      expect(status.geofence.latitude, 27.6766);
    });

    test('inactive when disabled', () async {
      final repo = AttendanceRepositoryImpl(
        api: _FakeApi(statusDto(geofenceEnabled: false)),
      );
      final status = await repo.getTodayStatus();
      expect(status.geofence.isActive, isFalse);
    });
  });
}
