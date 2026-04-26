import 'package:drift/drift.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/tables/sync_state_table.dart';

part 'sync_state_dao.g.dart';

@DriftAccessor(tables: <Type>[SyncState])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  Future<SyncStateRow?> get(String resource) {
    return (select(syncState)..where((s) => s.resource.equals(resource)))
        .getSingleOrNull();
  }

  Future<int> upsert(SyncStateCompanion entry) {
    return into(syncState).insertOnConflictUpdate(entry);
  }
}
