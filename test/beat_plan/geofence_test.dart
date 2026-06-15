import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/core/utils/geo_distance.dart';
import 'package:sales_sphere_erp/features/beat_plan/domain/beat_plan_stop.dart';

void main() {
  group('haversineMeters', () {
    test('is ~0 for the same point', () {
      expect(haversineMeters(27.7172, 85.3240, 27.7172, 85.3240), lessThan(0.01));
    });

    test('~111m for 0.001° of latitude', () {
      // 1° latitude ≈ 111.19 km, so 0.001° ≈ 111.2 m.
      final d = haversineMeters(27.7172, 85.3240, 27.7182, 85.3240);
      expect(d, closeTo(111.2, 1.0));
    });

    test('is symmetric', () {
      final a = haversineMeters(27.70, 85.30, 27.71, 85.31);
      final b = haversineMeters(27.71, 85.31, 27.70, 85.30);
      expect(a, closeTo(b, 0.0001));
    });
  });

  group('BeatPlanStop geofence', () {
    BeatPlanStop stopAt(double? lat, double? lng) => BeatPlanStop(
          id: 's1',
          beatPlanId: 'bp1',
          kind: 'CUSTOMER',
          status: 'PENDING',
          latitude: lat,
          longitude: lng,
        );

    test('distanceMetersFrom returns null without a stop location', () {
      expect(stopAt(null, null).distanceMetersFrom(27.7172, 85.3240), isNull);
    });

    test('distanceMetersFrom returns null without a rep position', () {
      expect(stopAt(27.7172, 85.3240).distanceMetersFrom(null, null), isNull);
    });

    test('isWithinRange: true when inside the radius, false when outside', () {
      final stop = stopAt(27.7172, 85.3240);
      // ~11 m north → within the default 50 m radius.
      expect(stop.isWithinRange(27.71730, 85.3240), isTrue);
      // ~220 m north → outside 50 m.
      expect(stop.isWithinRange(27.71920, 85.3240), isFalse);
    });

    test('isWithinRange is null when distance is unmeasurable', () {
      expect(stopAt(null, null).isWithinRange(27.7172, 85.3240), isNull);
    });
  });
}
