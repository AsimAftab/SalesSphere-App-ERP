import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/daos/targets_dao.dart';

TargetsCompanion _row({
  required String id,
  String dateKey = '',
  DateTime? fetchedAt,
}) {
  return TargetsCompanion(
    dateKey: Value(dateKey),
    id: Value(id),
    rule: const Value('No. of Orders'),
    metric: const Value('ORDER_COUNT'),
    interval: const Value('DAILY'),
    targetValue: const Value(99),
    actualValue: const Value(1),
    status: const Value('ACTIVE'),
    isCurrency: const Value(false),
    periodStart: Value(DateTime(2026, 7, 12)),
    periodEnd: Value(DateTime(2026, 7, 12)),
    periodLabel: const Value('Jul 12, 2026'),
    periodStatus: const Value('IN_PROGRESS'),
    fetchedAt: Value(fetchedAt ?? DateTime.now()),
  );
}

void main() {
  group('TargetsDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
    });

    tearDown(() async => db.close());

    test('replaceForDateKey replaces its key and leaves other keys alone',
        () async {
      await db.targetsDao.replaceForDateKey('', <TargetsCompanion>[
        _row(id: 't1'),
        _row(id: 't2'),
      ]);
      await db.targetsDao.replaceForDateKey('2026-07-10', <TargetsCompanion>[
        _row(dateKey: '2026-07-10', id: 't1'),
      ]);

      // Refresh the default key with a single different row.
      await db.targetsDao.replaceForDateKey('', <TargetsCompanion>[
        _row(id: 't3'),
      ]);

      final defaultRows = await db.targetsDao.rowsForDateKey('');
      expect(defaultRows.map((r) => r.id), <String>['t3']);

      // The explicit-date snapshot is untouched.
      final dayRows = await db.targetsDao.rowsForDateKey('2026-07-10');
      expect(dayRows.map((r) => r.id), <String>['t1']);
    });

    test('replacing with an empty list clears the key (target unassigned)',
        () async {
      await db.targetsDao
          .replaceForDateKey('', <TargetsCompanion>[_row(id: 't1')]);
      await db.targetsDao.replaceForDateKey('', const <TargetsCompanion>[]);

      expect(await db.targetsDao.rowsForDateKey(''), isEmpty);
    });

    test('same assignment id coexists under two dateKeys (composite PK)',
        () async {
      await db.targetsDao
          .replaceForDateKey('', <TargetsCompanion>[_row(id: 't1')]);
      await db.targetsDao.replaceForDateKey('2026-07-10', <TargetsCompanion>[
        _row(dateKey: '2026-07-10', id: 't1'),
      ]);

      expect(await db.targetsDao.rowsForDateKey(''), hasLength(1));
      expect(await db.targetsDao.rowsForDateKey('2026-07-10'), hasLength(1));
    });

    test('replace prunes snapshots older than staleAfter', () async {
      final stale = DateTime.now()
          .subtract(TargetsDao.staleAfter + const Duration(days: 1));
      await db.targetsDao.replaceForDateKey('2026-06-01', <TargetsCompanion>[
        _row(dateKey: '2026-06-01', id: 't1', fetchedAt: stale),
      ]);
      // Manually re-stamp fetchedAt because replaceForDateKey prunes AFTER
      // inserting — simulate a snapshot that has been sitting for 31 days.
      await db.update(db.targets).write(
            TargetsCompanion(fetchedAt: Value(stale)),
          );

      await db.targetsDao
          .replaceForDateKey('', <TargetsCompanion>[_row(id: 't2')]);

      expect(await db.targetsDao.rowsForDateKey('2026-06-01'), isEmpty);
      expect(await db.targetsDao.rowsForDateKey(''), hasLength(1));
    });

    test('deleteAll wipes every snapshot', () async {
      await db.targetsDao
          .replaceForDateKey('', <TargetsCompanion>[_row(id: 't1')]);
      await db.targetsDao.deleteAll();

      expect(await db.targetsDao.rowsForDateKey(''), isEmpty);
    });
  });
}
