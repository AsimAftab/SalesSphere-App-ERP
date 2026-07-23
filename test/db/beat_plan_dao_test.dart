import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';

void main() {
  group('BeatPlanDao', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.test(NativeDatabase.memory()));
    tearDown(() async => db.close());

    BeatPlansCompanion plan(String id) => BeatPlansCompanion.insert(
          id: id,
          name: 'Route A',
          scheduledDate: DateTime.utc(2026, 6, 14),
        );

    BeatPlanStopsCompanion stop(
      String id, {
      required String plan,
      String kind = 'CUSTOMER',
      String? status,
      int sortOrder = 0,
    }) =>
        BeatPlanStopsCompanion.insert(
          id: id,
          beatPlanId: plan,
          kind: kind,
          sortOrder: Value<int>(sortOrder),
          status: status == null ? const Value<String>.absent() : Value<String>(status),
        );

    test('upsertPlanWithStops persists plan + ordered stops', () async {
      await db.beatPlanDao.upsertPlanWithStops(plan('bp1'), <BeatPlanStopsCompanion>[
        stop('s2', plan: 'bp1', sortOrder: 1),
        stop('s1', plan: 'bp1'),
      ]);

      final row = await db.beatPlanDao.findById('bp1');
      expect(row, isNotNull);
      expect(row!.name, 'Route A');

      final stops = await db.beatPlanDao.stopsFor('bp1');
      expect(stops.map((s) => s.id).toList(), <String>['s1', 's2']);
    });

    test('markStopPending flags the stop and recomputes counters', () async {
      await db.beatPlanDao.upsertPlanWithStops(plan('bp1'), <BeatPlanStopsCompanion>[
        stop('s1', plan: 'bp1'),
        stop('s2', plan: 'bp1', sortOrder: 1),
      ]);

      await db.beatPlanDao.markStopPending(
        's1',
        status: 'VISITED',
        visitedAt: DateTime.utc(2026, 6, 14, 11),
      );

      final s1 = await db.beatPlanDao.findStop('s1');
      expect(s1!.status, 'VISITED');
      expect(s1.syncPending, true);

      final row = await db.beatPlanDao.findById('bp1');
      expect(row!.totalStops, 2);
      expect(row.visitedStops, 1);
    });

    test('a server refresh does not clobber a syncPending stop', () async {
      await db.beatPlanDao.upsertPlanWithStops(
        plan('bp1'),
        <BeatPlanStopsCompanion>[stop('s1', plan: 'bp1')],
      );
      await db.beatPlanDao.markStopPending('s1', status: 'VISITED');

      // Server still reports the stop PENDING (our write hasn't synced yet).
      await db.beatPlanDao.upsertPlanWithStops(
        plan('bp1'),
        <BeatPlanStopsCompanion>[stop('s1', plan: 'bp1', status: 'PENDING')],
      );

      final s1 = await db.beatPlanDao.findStop('s1');
      expect(s1!.status, 'VISITED'); // optimistic local state preserved
      expect(s1.syncPending, true);
    });

    test('markStopSyncSucceeded clears the pending flag', () async {
      await db.beatPlanDao.upsertPlanWithStops(
        plan('bp1'),
        <BeatPlanStopsCompanion>[stop('s1', plan: 'bp1')],
      );
      await db.beatPlanDao.markStopPending('s1', status: 'VISITED');
      await db.beatPlanDao.markStopSyncSucceeded('s1');

      final s1 = await db.beatPlanDao.findStop('s1');
      expect(s1!.syncPending, false);
      expect(s1.syncError, isNull);
    });
  });
}
