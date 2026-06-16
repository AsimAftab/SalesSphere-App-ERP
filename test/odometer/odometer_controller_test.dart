import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sales_sphere_erp/core/services/location_service.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_exceptions.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_monthly_report.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_today_status.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/domain/repositories/odometer_repository.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/controllers/odometer_controller.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/providers/odometer_providers.dart';

class _FakeRepo implements OdometerRepository {
  int startCalls = 0;
  double? lastReading;
  DistanceUnit? lastUnit;
  double? lastLatitude;
  String? lastImagePath;
  bool conflictOnStart = false;

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
    startCalls++;
    lastReading = startReading;
    lastUnit = unit;
    lastLatitude = latitude;
    lastImagePath = imagePath;
    if (conflictOnStart) {
      throw const OdometerConflictException('busy',
          code: 'ODOMETER_TRIP_IN_PROGRESS');
    }
    return const OdometerTrip(
      id: 't1',
      tripNumber: 1,
      status: OdometerStatus.inProgress,
      distanceUnit: DistanceUnit.km,
    );
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
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<OdometerTodayStatus> getTodayStatus() async =>
      const OdometerTodayStatus(trips: <OdometerTrip>[], hasActiveTrip: false);

  @override
  Future<OdometerMonthlyReport> getMonthlyReport(int year, int month) async =>
      OdometerMonthlyReport(
        month: month,
        year: year,
        records: const <OdometerTrip>[],
        summary: OdometerMonthlySummary.empty,
      );

  @override
  Future<OdometerTrip> getTripById(String id) => throw UnimplementedError();
}

class _FakeLocation extends LocationService {
  const _FakeLocation(this._position);
  final Position? _position;
  @override
  Future<Position?> getCurrentLocation() async => _position;
}

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 6, 17),
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
      odometerRepositoryProvider.overrideWithValue(repo),
      locationServiceProvider.overrideWithValue(_FakeLocation(position)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startTrip forwards parsed values + captured coordinates', () async {
    final repo = _FakeRepo();
    final c = _container(repo, _pos(27.7, 85.3));

    await c.read(odometerControllerProvider.notifier).startTrip(
          startReading: 15000,
          unit: DistanceUnit.km,
          imagePath: '/tmp/photo.jpg',
        );

    expect(repo.startCalls, 1);
    expect(repo.lastReading, 15000.0);
    expect(repo.lastUnit, DistanceUnit.km);
    expect(repo.lastLatitude, 27.7);
    expect(repo.lastImagePath, '/tmp/photo.jpg');
  });

  test('startTrip proceeds with null coordinates when no fix is available',
      () async {
    final repo = _FakeRepo();
    final c = _container(repo, null);

    await c.read(odometerControllerProvider.notifier).startTrip(
          startReading: 20,
          unit: DistanceUnit.miles,
        );

    expect(repo.startCalls, 1);
    expect(repo.lastLatitude, isNull);
    expect(repo.lastUnit, DistanceUnit.miles);
  });

  test('startTrip surfaces the conflict exception', () async {
    final repo = _FakeRepo()..conflictOnStart = true;
    final c = _container(repo, _pos(27.7, 85.3));

    await expectLater(
      c.read(odometerControllerProvider.notifier).startTrip(
            startReading: 1,
            unit: DistanceUnit.km,
          ),
      throwsA(isA<OdometerConflictException>()),
    );
  });
}
