import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/db/daos/beat_plan_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/outbox_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/parties_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/sync_state_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/tracking_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/tracking_pings_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/users_dao.dart';
import 'package:sales_sphere_erp/core/db/tables/beat_plan_stops_table.dart';
import 'package:sales_sphere_erp/core/db/tables/beat_plans_table.dart';
import 'package:sales_sphere_erp/core/db/tables/mutation_outbox_table.dart';
import 'package:sales_sphere_erp/core/db/tables/parties_table.dart';
import 'package:sales_sphere_erp/core/db/tables/sync_state_table.dart';
import 'package:sales_sphere_erp/core/db/tables/tracking_pings_table.dart';
import 'package:sales_sphere_erp/core/db/tables/tracking_sessions_table.dart';
import 'package:sales_sphere_erp/core/db/tables/tracking_summaries_table.dart';
import 'package:sales_sphere_erp/core/db/tables/users_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    Users,
    MutationOutbox,
    SyncState,
    Parties,
    BeatPlans,
    BeatPlanStops,
    TrackingSessions,
    TrackingPings,
    TrackingSummaries,
  ],
  daos: <Type>[
    UsersDao,
    OutboxDao,
    SyncStateDao,
    PartiesDao,
    BeatPlanDao,
    TrackingDao,
    TrackingPingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.test(super.connection);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          // Two isolates (UI + background tracking service) open their own
          // connection to this file under WAL. A generous busy_timeout lets a
          // writer wait for the other's lock instead of throwing SQLITE_BUSY.
          await customStatement('PRAGMA busy_timeout = 5000');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Re-shape `users` to match what /auth/login actually returns:
            // drop the placeholder profile columns, add emailVerified +
            // systemRole. Cached rows are discarded — the session token
            // plus /auth/me repopulates on next cold start.
            await m.deleteTable('users');
            await m.createTable(users);
          }
          if (from < 4) {
            // v3 introduced `parties` + `party_images` with the full Customer
            // shape. v4 drops the image gallery and slims `parties` to the
            // 12 fields the mobile UI actually consumes. Drop both old
            // tables (DROP IF EXISTS — safe even if v3 was skipped on a
            // direct v2→v4 hop) and create the slim parties.
            await m.deleteTable('party_images');
            await m.deleteTable('parties');
            await m.createTable(parties);
          }
          if (from < 5) {
            // v5 re-adds `partyType` as a flat name column on parties
            // (backend now embeds `customerType: { id, name }` in every
            // customer payload, and the form picker reads/writes the name).
            await m.addColumn(parties, parties.partyType);
          }
          if (from < 6) {
            // v6 wires offline-first writes: every party row can flag
            // itself as "pending sync" (UI shows an orange badge) and
            // carry the last sync failure for dead-letter rows
            // (UI flips to red). Outbox handler reconciles both columns.
            await m.addColumn(parties, parties.syncPending);
            await m.addColumn(parties, parties.syncError);
          }
          if (from < 7) {
            // v7 adds the beat-plan cache (plans + stops) and the live
            // tracking tables: the session mirror, the durable GPS ping
            // outbox, and completed-session summaries.
            await m.createTable(beatPlans);
            await m.createTable(beatPlanStops);
            await m.createTable(trackingSessions);
            await m.createTable(trackingPings);
            await m.createTable(trackingSummaries);
          }
          if (from < 8) {
            // v8 enriches a stop's visit: start time + server-computed
            // duration, notes, optional follow-up date, and the proof photo.
            await m.addColumn(beatPlanStops, beatPlanStops.visitStartedAt);
            await m.addColumn(beatPlanStops, beatPlanStops.visitDurationSec);
            await m.addColumn(beatPlanStops, beatPlanStops.visitNotes);
            await m.addColumn(beatPlanStops, beatPlanStops.followUpDate);
            await m.addColumn(beatPlanStops, beatPlanStops.visitImageUrl);
          }
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

final partiesDaoProvider = Provider<PartiesDao>(
  (ref) => ref.watch(appDatabaseProvider).partiesDao,
);

final beatPlanDaoProvider = Provider<BeatPlanDao>(
  (ref) => ref.watch(appDatabaseProvider).beatPlanDao,
);

final trackingDaoProvider = Provider<TrackingDao>(
  (ref) => ref.watch(appDatabaseProvider).trackingDao,
);

final trackingPingsDaoProvider = Provider<TrackingPingsDao>(
  (ref) => ref.watch(appDatabaseProvider).trackingPingsDao,
);
