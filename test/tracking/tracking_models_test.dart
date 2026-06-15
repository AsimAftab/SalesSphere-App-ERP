import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/tracking/domain/tracking_live_state.dart';
import 'package:sales_sphere_erp/features/tracking/domain/tracking_models.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_ipc.dart';

void main() {
  group('LocationFix payloads', () {
    final fix = LocationFix(
      clientPingId: 'p1',
      latitude: 27.7,
      longitude: 85.3,
      recordedAt: DateTime.utc(2026, 6, 14, 10),
      accuracy: 5,
      speed: 1.2,
      heading: 90,
    );

    test('toLiveJson carries beatPlanId + the idempotency key', () {
      final json = fix.toLiveJson('bp1');
      expect(json['beatPlanId'], 'bp1');
      expect(json['latitude'], 27.7);
      expect(json['clientPingId'], 'p1');
      expect(json['recordedAt'], '2026-06-14T10:00:00.000Z');
      expect(json.containsKey('address'), false); // omitted when null
    });

    test('toPingJson (batch element) omits beatPlanId', () {
      final json = fix.toPingJson();
      expect(json.containsKey('beatPlanId'), false);
      expect(json['clientPingId'], 'p1');
    });

    test('batteryLevel is included when set and omitted when null', () {
      final withBattery = LocationFix(
        clientPingId: 'p2',
        latitude: 27.7,
        longitude: 85.3,
        recordedAt: DateTime.utc(2026, 6, 14, 10),
        batteryLevel: 85,
      );
      expect(withBattery.toPingJson()['batteryLevel'], 85);
      expect(withBattery.toLiveJson('bp1')['batteryLevel'], 85);
      // The base fix has no battery → key omitted.
      expect(fix.toPingJson().containsKey('batteryLevel'), false);
    });
  });

  group('wire enum mapping', () {
    test('ForceStopReason.fromWire', () {
      expect(
        ForceStopReason.fromWire('attendance_checkout'),
        ForceStopReason.attendanceCheckout,
      );
      expect(ForceStopReason.fromWire('mystery'), ForceStopReason.unknown);
    });

    test('TrackingStatus.fromWire defaults to active', () {
      expect(TrackingStatus.fromWire('PAUSED'), TrackingStatus.paused);
      expect(TrackingStatus.fromWire(null), TrackingStatus.active);
    });
  });

  group('TrackingAck', () {
    test('exposes persisted/deduped/sessionId/summary', () {
      const ack = TrackingAck(
        ok: true,
        data: <String, dynamic>{
          'persisted': 3,
          'deduped': 2,
          'sessionId': 's1',
          'summary': <String, dynamic>{
            'totalDistanceKm': 1.5,
            'totalDurationMin': 30,
            'averageSpeedKmh': 3.0,
            'directoriesVisited': 2,
          },
        },
      );
      expect(ack.persisted, 3);
      expect(ack.deduped, 2);
      expect(ack.sessionId, 's1');
      expect(ack.summary!.totalDistanceKm, 1.5);
      expect(ack.summary!.directoriesVisited, 2);
    });
  });

  group('TrackingLiveState.fromMap', () {
    test('rebuilds from the service payload', () {
      final state = TrackingLiveState.fromMap(<String, dynamic>{
        TrackingIpc.kBeatPlanId: 'bp1',
        TrackingIpc.kStatus: 'active',
        TrackingIpc.kConnected: true,
        TrackingIpc.kDistanceKm: 2.0,
        TrackingIpc.kDurationSec: 3600,
        TrackingIpc.kQueued: 0,
        TrackingIpc.kTotal: 5,
        TrackingIpc.kVisited: 2,
        TrackingIpc.kSkipped: 1,
      });
      expect(state.isTracking, true);
      expect(state.isFor('bp1'), true);
      expect(state.connected, true);
      expect(state.durationLabel, '1h 0m');
    });

    test('completed status is not "tracking"', () {
      final state = TrackingLiveState.fromMap(<String, dynamic>{
        TrackingIpc.kBeatPlanId: 'bp1',
        TrackingIpc.kStatus: 'completed',
      });
      expect(state.isTracking, false);
    });
  });
}
