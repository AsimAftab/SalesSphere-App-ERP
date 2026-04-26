import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';

void main() {
  group('UsersDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
    });

    tearDown(() async => db.close());

    test('upsert + watchById streams the inserted user', () async {
      final stream = db.usersDao.watchById('user-1');
      final emissions = <UserRow?>[];
      final sub = stream.listen(emissions.add);

      await db.usersDao.upsert(
        UsersCompanion(
          id: const Value('user-1'),
          email: const Value('asim@example.com'),
          fullName: const Value('Asim Aftab'),
          updatedAt: Value(DateTime.utc(2026, 4, 26)),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      final last = emissions.last;
      expect(last, isNotNull);
      expect(last!.id, 'user-1');
      expect(last.email, 'asim@example.com');
      expect(last.fullName, 'Asim Aftab');
    });

    test('upsert overwrites existing row', () async {
      await db.usersDao.upsert(
        UsersCompanion(
          id: const Value('user-1'),
          email: const Value('old@example.com'),
          fullName: const Value('Old Name'),
          updatedAt: Value(DateTime.utc(2026, 4, 26)),
        ),
      );
      await db.usersDao.upsert(
        UsersCompanion(
          id: const Value('user-1'),
          email: const Value('new@example.com'),
          fullName: const Value('New Name'),
          updatedAt: Value(DateTime.utc(2026, 4, 27)),
        ),
      );
      final row = await db.usersDao.findById('user-1');
      expect(row!.email, 'new@example.com');
      expect(row.fullName, 'New Name');
    });
  });
}
