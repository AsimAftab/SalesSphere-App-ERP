import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/odometer/data/dto/odometer_monthly_report_dto.dart';
import 'package:sales_sphere_erp/features/odometer/data/dto/odometer_record_dto.dart';
import 'package:sales_sphere_erp/features/odometer/data/dto/odometer_today_status_dto.dart';
import 'package:sales_sphere_erp/features/odometer/data/odometer_api.dart';
import 'package:sales_sphere_erp/features/odometer/data/repositories/odometer_repository_impl.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_exceptions.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_status.dart';

/// Fake API: only the methods exercised per test are populated; the rest throw.
class _FakeApi implements OdometerApi {
  _FakeApi({
    this.todayStatus,
    this.tripById,
    this.startError,
  });

  OdometerTodayStatusDto? todayStatus;
  OdometerRecordDto? tripById;
  DioException? startError;

  @override
  Future<OdometerTodayStatusDto> fetchTodayStatus() async => todayStatus!;

  @override
  Future<OdometerRecordDto> fetchById(String id) async => tripById!;

  @override
  Future<OdometerRecordDto> start({
    required double startReading,
    required String unit,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? imagePath,
  }) async {
    if (startError != null) throw startError!;
    throw UnimplementedError();
  }

  @override
  Future<OdometerMonthlyReportDto> fetchMonthlyReport(int year, int month) =>
      throw UnimplementedError();

  @override
  Future<OdometerRecordDto> stop({
    required double stopReading,
    required String unit,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? imagePath,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

DioException _dioError(int status, Map<String, dynamic> body, {Object? mapped}) {
  final req = RequestOptions(path: '/odometer/start');
  return DioException(
    requestOptions: req,
    response: Response<Map<String, dynamic>>(
      requestOptions: req,
      statusCode: status,
      data: body,
    ),
    type: DioExceptionType.badResponse,
    error: mapped,
  );
}

Map<String, dynamic> _completedJson() => <String, dynamic>{
      'id': 'odo_1',
      'employeeId': 'emp_1',
      'date': '2026-06-17',
      'tripNumber': 1,
      'status': 'completed',
      'startReading': 15000,
      'startUnit': 'km',
      'startImage': 'https://img/start.jpg',
      'startTime': '2026-06-17T03:49:00.000Z',
      'startLocation': <String, dynamic>{
        'latitude': 27.7,
        'longitude': 85.3,
        'address': 'Kathmandu',
      },
      'stopReading': 15025.5,
      'stopUnit': 'km',
      'distance': 25.5,
      'createdAt': '2026-06-17T03:49:00.000Z',
      'updatedAt': '2026-06-17T06:10:00.000Z',
    };

void main() {
  group('getTripById → DTO→domain mapping', () {
    test('maps a completed trip with lowercase enums + location', () async {
      final repo = OdometerRepositoryImpl(
        api: _FakeApi(tripById: OdometerRecordDto.fromJson(_completedJson())),
      );

      final trip = await repo.getTripById('odo_1');

      expect(trip.id, 'odo_1');
      expect(trip.tripNumber, 1);
      expect(trip.status, OdometerStatus.completed);
      expect(trip.distanceUnit, DistanceUnit.km);
      expect(trip.startReading, 15000.0);
      expect(trip.stopReading, 15025.5);
      expect(trip.distance, 25.5);
      expect(trip.startImageUrl, 'https://img/start.jpg');
      expect(trip.startLocation?.latitude, 27.7);
      expect(trip.startLocation?.address, 'Kathmandu');
      // No stopLocation in the payload → null.
      expect(trip.stopLocation, isNull);
    });

    test('in-progress trip carries miles unit and null distance', () async {
      final json = _completedJson()
        ..['status'] = 'in_progress'
        ..['startUnit'] = 'miles'
        ..remove('stopReading')
        ..remove('stopUnit')
        ..remove('distance');
      final repo = OdometerRepositoryImpl(
        api: _FakeApi(tripById: OdometerRecordDto.fromJson(json)),
      );

      final trip = await repo.getTripById('odo_1');

      expect(trip.status, OdometerStatus.inProgress);
      expect(trip.distanceUnit, DistanceUnit.miles);
      expect(trip.stopReading, isNull);
      expect(trip.distance, isNull);
    });

    test('unknown status wire value throws loudly', () async {
      final json = _completedJson()..['status'] = 'bogus';
      final repo = OdometerRepositoryImpl(
        api: _FakeApi(tripById: OdometerRecordDto.fromJson(json)),
      );

      await expectLater(
        repo.getTripById('odo_1'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('getTodayStatus', () {
    test('sorts trips by tripNumber and exposes the active trip', () async {
      final t2 = _completedJson()
        ..['id'] = 'odo_2'
        ..['tripNumber'] = 2
        ..['status'] = 'in_progress';
      final today = OdometerTodayStatusDto.fromJson(<String, dynamic>{
        'trips': <dynamic>[t2, _completedJson()],
        'hasActiveTrip': true,
        'activeTripId': 'odo_2',
      });
      final repo = OdometerRepositoryImpl(api: _FakeApi(todayStatus: today));

      final status = await repo.getTodayStatus();

      expect(status.trips.map((t) => t.tripNumber), <int>[1, 2]);
      expect(status.hasActiveTrip, isTrue);
      expect(status.activeTrip?.id, 'odo_2');
      expect(status.completedTrips.length, 1);
    });
  });

  group('write errors → typed domain exceptions', () {
    test('409 ODOMETER_TRIP_IN_PROGRESS → OdometerConflictException', () async {
      final repo = OdometerRepositoryImpl(
        api: _FakeApi(
          startError: _dioError(409, <String, dynamic>{
            'success': false,
            'error': <String, dynamic>{
              'code': 'ODOMETER_TRIP_IN_PROGRESS',
              'message': 'You already have an open trip today.',
            },
          }),
        ),
      );

      await expectLater(
        repo.startTrip(startReading: 10, unit: DistanceUnit.km),
        throwsA(
          isA<OdometerConflictException>()
              .having((e) => e.code, 'code', 'ODOMETER_TRIP_IN_PROGRESS'),
        ),
      );
    });

    test('generic error unwraps the interceptor ApiException', () async {
      final repo = OdometerRepositoryImpl(
        api: _FakeApi(
          startError: _dioError(
            500,
            <String, dynamic>{'success': false},
            mapped: const ServerException(),
          ),
        ),
      );

      await expectLater(
        repo.startTrip(startReading: 10, unit: DistanceUnit.km),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
