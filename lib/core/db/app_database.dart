import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/db/daos/outbox_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/sync_state_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/users_dao.dart';
import 'package:sales_sphere_erp/core/db/tables/mutation_outbox_table.dart';
import 'package:sales_sphere_erp/core/db/tables/sync_state_table.dart';
import 'package:sales_sphere_erp/core/db/tables/users_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[Users, MutationOutbox, SyncState],
  daos: <Type>[UsersDao, OutboxDao, SyncStateDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.test(super.connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Add migrations as schemaVersion bumps.
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'salessphere',
      native: const DriftNativeOptions(),
    );
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final usersDaoProvider = Provider<UsersDao>(
  (ref) => ref.watch(appDatabaseProvider).usersDao,
);

final outboxDaoProvider = Provider<OutboxDao>(
  (ref) => ref.watch(appDatabaseProvider).outboxDao,
);

final syncStateDaoProvider = Provider<SyncStateDao>(
  (ref) => ref.watch(appDatabaseProvider).syncStateDao,
);
