import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/attendance/data/attendance_api.dart';
import 'package:sales_sphere_erp/features/attendance/data/dto/attendance_record_dto.dart';
import 'package:sales_sphere_erp/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_exceptions.dart';

/// Fakes the HTTP layer so we can drive the repository with hand-built DTOs /
/// errors and assert the domain mapping + structured-error translation.
class _FakeApi implements AttendanceApi {
  _FakeApi({this.todayStatus, this.checkInError, this.checkOutError});

  AttendanceTodayStatusDto? todayStatus;
  DioException? checkInError;
  DioException? checkOutError;

  @override
  Future<AttendanceTodayStatusDto> fetchTodayStatus() async => todayStatus!;

  @override
  Future<MonthlyReportDto> fetchMonthlyReport(int year, int month) =>
      throw UnimplementedError();

  @override
  Future<AttendanceRecordDto> checkIn({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    if (checkInError != null) throw checkInError!;
    return _okRecord();
  }

  @override
  Future<AttendanceRecordDto> checkOut({
    required double latitude,
    required double longitude,
    required String address,
    required bool isHalfDay,
  }) async {
    if (checkOutError != null) throw checkOutError!;
    return _okRecord();
  }

  AttendanceRecordDto _okRecord() => AttendanceRecordDto(
        id: 'att_ok',
        date: DateTime(2026, 6, 16),
        status: 'PRESENT',
        checkInAt: DateTime(2026, 6, 16, 9),
      );
}

DioException _apiError(int status, Map<String, dynamic> body) {
  final req = RequestOptions(path: '/attendance/check-out');
  return DioException(
    requestOptions: req,
    response: Response<Map<String, dynamic>>(
      requestOptions: req,
      statusCode: status,
      data: body,
    ),
    type: DioExceptionType.badResponse,
  );
}

AttendanceTodayStatusDto statusDto({bool geofence = true}) =>
    AttendanceTodayStatusDto(
      record: null,
      geofenceEnabled: geofence,
      geofenceLatitude: 27.6766,
      geofenceLongitude: 85.316,
      geofenceAddress: 'HQ',
      geofenceGoogleMapLink: null,
    );

void main() {
  group('getTodayStatus → geofence mapping', () {
    test('active when enabled with an anchor', () async {
      final repo = AttendanceRepositoryImpl(api: _FakeApi(todayStatus: statusDto()));
      final status = await repo.getTodayStatus();
      expect(status.geofence.isActive, isTrue);
      expect(status.geofence.latitude, 27.6766);
      expect(status.record, isNull);
    });

    test('inactive when disabled', () async {
      final repo = AttendanceRepositoryImpl(
        api: _FakeApi(todayStatus: statusDto(geofence: false)),
      );
      final status = await repo.getTodayStatus();
      expect(status.geofence.isActive, isFalse);
    });
  });

  group('write errors → typed domain exceptions', () {
    test('checkout restriction with half-day fallback', () async {
      final repo = AttendanceRepositoryImpl(
        api: _FakeApi(
          checkOutError: _apiError(422, <String, dynamic>{
            'success': false,
            'error': <String, dynamic>{
              'code': 'ATTENDANCE_CHECKOUT_RESTRICTED',
              'message': 'Full-day checkout is not allowed yet.',
              'details': <String, dynamic>{
                'reason': 'FULL_DAY_NOT_OPEN',
                'canUseHalfDayFallback': true,
                'fullDayAllowedFrom': '16:30',
                'halfDayAllowedFrom': '12:30',
              },
            },
          }),
        ),
      );

      await expectLater(
        repo.checkOut(latitude: 0, longitude: 0, address: 'x', isHalfDay: false),
        throwsA(
          isA<CheckOutRestrictionException>()
              .having((e) => e.reason, 'reason', CheckOutDeniedReason.fullDayNotOpen)
              .having((e) => e.canUseHalfDayFallback, 'fallback', isTrue)
              .having((e) => e.fullDayAllowedFrom, 'fullDayAllowedFrom', '16:30'),
        ),
      );
    });

    test('check-in restriction maps the reason', () async {
      final repo = AttendanceRepositoryImpl(
        api: _FakeApi(
          checkInError: _apiError(422, <String, dynamic>{
            'success': false,
            'error': <String, dynamic>{
              'code': 'ATTENDANCE_CHECKIN_RESTRICTED',
              'message': 'Too early.',
              'details': <String, dynamic>{
                'reason': 'TOO_EARLY',
                'allowedFrom': '07:00',
              },
            },
          }),
        ),
      );

      await expectLater(
        repo.checkIn(latitude: 0, longitude: 0, address: 'x'),
        throwsA(
          isA<CheckInRestrictionException>()
              .having((e) => e.reason, 'reason', CheckInDeniedReason.tooEarly)
              .having((e) => e.allowedFrom, 'allowedFrom', '07:00'),
        ),
      );
    });

    test('409 conflict maps to AttendanceConflictException', () async {
      final repo = AttendanceRepositoryImpl(
        api: _FakeApi(
          checkOutError: _apiError(409, <String, dynamic>{
            'success': false,
            'error': <String, dynamic>{
              'code': 'ATTENDANCE_ALREADY_CHECKED_OUT',
              'message': 'You have already checked out today.',
            },
          }),
        ),
      );

      await expectLater(
        repo.checkOut(latitude: 0, longitude: 0, address: 'x', isHalfDay: false),
        throwsA(
          isA<AttendanceConflictException>()
              .having((e) => e.code, 'code', 'ATTENDANCE_ALREADY_CHECKED_OUT'),
        ),
      );
    });
  });
}
