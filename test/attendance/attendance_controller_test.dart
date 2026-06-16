import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_record.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/attendance_today_status.dart';
import 'package:sales_sphere_erp/features/attendance/domain/geofence_config.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_report.dart';
import 'package:sales_sphere_erp/features/attendance/domain/monthly_summary.dart';
import 'package:sales_sphere_erp/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/providers/attendance_providers.dart';

// Office anchor used across the geofence cases.
const _orgLat = 27.7172;
const _orgLng = 85.3240;

class _FakeRepo implements AttendanceRepository {
  _FakeRepo({required bool geofenceEnabled})
      : _status = AttendanceTodayStatus(
          record: null,
          geofence: GeofenceConfig(
            enabled: geofenceEnabled,
            latitude: _orgLat,
            longitude: _orgLng,
          ),
        );

  final AttendanceTodayStatus _status;
  int checkInCalls = 0;
  ({double lat, double lng, String address})? lastCheckIn;

  @override
  Future<AttendanceTodayStatus> getTodayStatus() async => _status;

  @override
  Future<AttendanceRecord> checkIn({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    checkInCalls++;
    lastCheckIn = (lat: latitude, lng: longitude, address: address);
    return AttendanceRecord(
      id: 'r1',
      date: DateTime(2026, 6, 15),
      status: AttendanceStatus.present,
      checkInAt: DateTime(2026, 6, 15, 10),
      checkInLat: latitude,
      checkInLng: longitude,
      checkInAddress: address,
    );
  }

  @override
  Future<AttendanceRecord> checkOut({
    required double latitude,
    required double longitude,
    required String address,
    required bool isHalfDay,
  }) =>
      throw UnimplementedError();

  @override
  Future<MonthlyReport> getMonthlyReport(int year, int month) async =>
      const MonthlyReport(records: <AttendanceRecord>[], summary: MonthlySummary.empty);
}

class _FakeLocation extends LocationService {
  _FakeLocation(this._position);
  final Position? _position;
  @override
  Future<Position?> getCurrentLocation() async => _position;
}

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 6, 15),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

ProviderContainer _container(_FakeRepo repo, Position? position) {
  final c = ProviderContainer(
    overrides: [
      attendanceRepositoryProvider.overrideWithValue(repo),
      locationServiceProvider.overrideWithValue(_FakeLocation(position)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  // reverseGeocodeAddress touches a platform channel; the binding lets it
  // fail gracefully (→ coordinate fallback address) instead of crashing.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('geofence inactive → check-in proceeds regardless of distance', () async {
    final repo = _FakeRepo(geofenceEnabled: false);
    final c = _container(repo, _pos(0, 0)); // far from the anchor
    await c.read(attendanceControllerProvider.notifier).checkIn();
    expect(repo.checkInCalls, 1);
  });

  test('geofence active + within radius → check-in proceeds', () async {
    final repo = _FakeRepo(geofenceEnabled: true);
    final c = _container(repo, _pos(_orgLat, _orgLng)); // 0 m away
    await c.read(attendanceControllerProvider.notifier).checkIn();
    expect(repo.checkInCalls, 1);
    expect(repo.lastCheckIn!.lat, _orgLat);
  });

  test('geofence active + outside radius → throws, no write', () async {
    final repo = _FakeRepo(geofenceEnabled: true);
    final c = _container(repo, _pos(27.6766, 85.316)); // ~4.5 km away
    await expectLater(
      c.read(attendanceControllerProvider.notifier).checkIn(),
      throwsA(isA<OutsideGeofenceException>()),
    );
    expect(repo.checkInCalls, 0);
  });

  test('no location fix → throws LocationUnavailableException, no write', () async {
    final repo = _FakeRepo(geofenceEnabled: false);
    final c = _container(repo, null);
    await expectLater(
      c.read(attendanceControllerProvider.notifier).checkIn(),
      throwsA(isA<LocationUnavailableException>()),
    );
    expect(repo.checkInCalls, 0);
  });
}
