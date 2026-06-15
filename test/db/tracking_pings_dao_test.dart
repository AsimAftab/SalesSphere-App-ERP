import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';

void main() {
  group('TrackingPingsDao (GPS outbox)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.test(NativeDatabase.memory()));
    tearDown(() async => db.close());

    TrackingPingsCompanion ping(
      String id, {
      required String plan,
      required DateTime at,
      int? battery,
    }) =>
        TrackingPingsCompanion.insert(
          clientPingId: id,
          beatPlanId: plan,
          latitude: 27.7,
          longitude: 85.3,
          recordedAt: at,
          batteryLevel: Value<int?>(battery),
        );

    test('enqueue buffers pings and counts them', () async {
      await db.trackingPingsDao
          .enqueue(ping('a', plan: 'bp1', at: DateTime.utc(2026, 6, 14, 10)));
      await db.trackingPingsDao
          .enqueue(ping('b', plan: 'bp1', at: DateTime.utc(2026, 6, 14, 10, 1)));
      expect(await db.trackingPingsDao.countPending(), 2);
    });

    test('enqueue round-trips the battery level for batch replay', () async {
      await db.trackingPingsDao.enqueue(
        ping('a', plan: 'bp1', at: DateTime.utc(2026, 6, 14, 10), battery: 73),
      );
      await db.trackingPingsDao
          .enqueue(ping('b', plan: 'bp1', at: DateTime.utc(2026, 6, 14, 10, 1)));
      final rows = await db.trackingPingsDao.pending();
      expect(rows.firstWhere((r) => r.clientPingId == 'a').batteryLevel, 73);
      // A ping captured with no battery reading stays null.
      expect(rows.firstWhere((r) => r.clientPingId == 'b').batteryLevel, isNull);
    });

    test('enqueue dedupes on clientPingId (idempotent replay)', () async {
      await db.trackingPingsDao
          .enqueue(ping('a', plan: 'bp1', at: DateTime.utc(2026, 6, 14, 10)));
      await db.trackingPingsDao
          .enqueue(ping('a', plan: 'bp1', at: DateTime.utc(2026, 6, 14, 10, 5)));
      expect(await db.trackingPingsDao.countPending(), 1);
    });

    test('pending returns oldest-first for chronological replay', () async {
      await db.trackingPingsDao
          .enqueue(ping('b', plan: 'bp1', at: DateTime.utc(2026, 6, 14, 10, 2)));
      await db.trackingPingsDao
          .enqueue(ping('a', plan: 'bp1', at: DateTime.utc(2026, 6, 14, 10, 1)));
      final rows = await db.trackingPingsDao.pending();
      expect(rows.map((r) => r.clientPingId).toList(), <String>['a', 'b']);
    });

    test('deleteByClientIds removes only acked pings', () async {
      await db.trackingPingsDao
          .enqueue(ping('a', plan: 'bp1', at: DateTime.utc(2026, 6, 14, 10)));
      await db.trackingPingsDao
          .enqueue(ping('b', plan: 'bp1', at: DateTime.utc(2026, 6, 14, 10, 1)));
      await db.trackingPingsDao.deleteByClientIds(<String>['a']);
      final rows = await db.trackingPingsDao.pending();
      expect(rows.single.clientPingId, 'b');
    });

    test('clearForBeatPlan only clears that plan', () async {
      await db.trackingPingsDao
          .enqueue(ping('a', plan: 'bp1', at: DateTime.utc(2026, 6, 14, 10)));
      await db.trackingPingsDao
          .enqueue(ping('b', plan: 'bp2', at: DateTime.utc(2026, 6, 14, 10)));
      await db.trackingPingsDao.clearForBeatPlan('bp1');
      final rows = await db.trackingPingsDao.pending();
      expect(rows.single.beatPlanId, 'bp2');
    });
  });
}
