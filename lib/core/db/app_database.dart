import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/db/daos/beat_plan_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/collections_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/outbox_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/parties_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/sync_state_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/tracking_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/tracking_pings_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/users_dao.dart';
import 'package:sales_sphere_erp/core/db/tables/beat_plan_stops_table.dart';
import 'package:sales_sphere_erp/core/db/tables/beat_plans_table.dart';
import 'package:sales_sphere_erp/core/db/tables/collections_table.dart';
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
    Collections,
    CollectionAllocations,
  ],
  daos: <Type>[
    UsersDao,
    OutboxDao,
    SyncStateDao,
    PartiesDao,
    BeatPlanDao,
    TrackingDao,
    TrackingPingsDao,
    CollectionsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.test(super.connection);

  @override
  int get schemaVersion => 11;

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
            await _addColumnIfMissing(m, parties, parties.partyType);
          }
          if (from < 6) {
            // v6 wires offline-first writes: every party row can flag
            // itself as "pending sync" (UI shows an orange badge) and
            // carry the last sync failure for dead-letter rows
            // (UI flips to red). Outbox handler reconciles both columns.
            await _addColumnIfMissing(m, parties, parties.syncPending);
            await _addColumnIfMissing(m, parties, parties.syncError);
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
          if (from == 7) {
            // v8 enriches a stop's visit: start time + server-computed
            // duration, notes, optional follow-up date, and the proof photo.
            // Guarded to exactly v7→v8: the `from < 7` block above already
            // creates beatPlanStops with the current (v8) schema, so a direct
            // v6→v8 hop must NOT re-add these columns (duplicate-column error).
            await _addColumnIfMissing(m, beatPlanStops, beatPlanStops.visitStartedAt);
            await _addColumnIfMissing(m, beatPlanStops, beatPlanStops.visitDurationSec);
            await _addColumnIfMissing(m, beatPlanStops, beatPlanStops.visitNotes);
            await _addColumnIfMissing(m, beatPlanStops, beatPlanStops.followUpDate);
            await _addColumnIfMissing(m, beatPlanStops, beatPlanStops.visitImageUrl);
          }
          if (from >= 7 && from < 9) {
            // v9 adds the device battery level (0–100) to each GPS ping so
            // watchers can see when a rep's phone is about to die mid-route.
            // Same guard rationale as the v8 block: only run when trackingPings
            // was created by the pre-v9 `from < 7` block (i.e. upgrading from
            // exactly v7 or v8). A direct v6→v9 hop creates the table with the
            // current schema — which already has this column — so re-adding it
            // would raise a duplicate-column error.
            await _addColumnIfMissing(m, trackingPings, trackingPings.batteryLevel);
          }
          if (from >= 7 && from < 10) {
            // v10 records when a stop was skipped (`skippedAt`) — the server
            // leaves `visitedAt` null for a skip, so the card needs its own
            // timestamp to show "Skipped at …". Same guard rationale as the v8
            // block: only run when beatPlanStops was created by the pre-v10
            // `from < 7` block (upgrading from v7/v8/v9). A direct v6→v10 hop
            // creates the table with the current schema — which already has
            // this column — so re-adding it would raise a duplicate-column error.
            await _addColumnIfMissing(m, beatPlanStops, beatPlanStops.skippedAt);
          }
          if (from < 11) {
            // v11 adds the collections cache shared by both collection
            // modules (`kind` discriminates on-account vs invoice-allocated),
            // plus the child allocation table Collection Plus writes into.
            //
            // New tables use `createTable`, not `_addColumnIfMissing` — that
            // guard exists for `addColumn`, which has no IF NOT EXISTS form.
            await m.createTable(collections);
            await m.createTable(collectionAllocations);
          }
        },
      );

  /// Adds [column] to [table] only if it isn't already present.
  ///
  /// The UI isolate and the background tracking-service isolate each open their
  /// own connection to this file, so on the first launch after a schema bump
  /// BOTH run `onUpgrade`. A plain `addColumn` lets the isolate that loses the
  /// race fail with "duplicate column", which crashes its DB open — e.g. the
  /// tracking isolate's `start()` throws before it can report a live session,
  /// leaving the beat-plan page stuck on "Resuming live tracking…" until the
  /// app is restarted. Guarding on `PRAGMA table_info` makes each column add
  /// idempotent so a concurrent (or repeated) run is harmless.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final info = await m.database
        .customSelect('PRAGMA table_info(${table.actualTableName})')
        .get();
    final present = info.any((row) => row.data['name'] == column.name);
    if (!present) await m.addColumn(table, column);
  }

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

/// Shared by both collection modules — rows are discriminated by
/// `CollectionKind`, so `/collections` and `/collection-plus` never see each
/// other's cache entries.
final collectionsDaoProvider = Provider<CollectionsDao>(
  (ref) => ref.watch(appDatabaseProvider).collectionsDao,
);
