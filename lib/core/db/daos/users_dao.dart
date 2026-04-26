import 'package:drift/drift.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/tables/users_table.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: <Type>[Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Stream<UserRow?> watchById(String id) {
    return (select(users)..where((u) => u.id.equals(id))).watchSingleOrNull();
  }

  Future<UserRow?> findById(String id) {
    return (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  Future<int> upsert(UsersCompanion entry) {
    return into(users).insertOnConflictUpdate(entry);
  }

  Future<int> deleteAll() => delete(users).go();
}
