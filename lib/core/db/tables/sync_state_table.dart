import 'package:drift/drift.dart';

/// Stores the last-known server cursor / etag per resource family, so the
/// sync engine can do delta pulls instead of full reloads.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get resource => text()(); // e.g. 'parties', 'beat_plans'
  TextColumn get cursor => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{resource};
}
