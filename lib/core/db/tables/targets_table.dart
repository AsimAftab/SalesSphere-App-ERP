import 'package:drift/drift.dart';

/// Offline read cache for `GET /targets/me` — a **cache, not an outbox**.
/// Targets are read-only on mobile (assigned by an admin on web), so there is
/// no sync state here: rows are wholesale-replaced on every successful fetch
/// and only ever served back when the network is unreachable.
///
/// Achievement is computed live server-side on every read; these rows go
/// stale the moment the rep books an order, which is fine for an offline
/// fallback and wrong for anything else — never serve them while online.
@DataClassName('TargetRow')
class Targets extends Table {
  /// The requested date this snapshot answers: `''` for the default fetch
  /// (no `?date` param — the server resolved "today" in the org's timezone),
  /// else the exact `YYYY-MM-DD` sent. A refresh replaces all rows for its
  /// key and touches no other key, so offline day-navigation only shows days
  /// the rep actually viewed.
  TextColumn get dateKey => text().withDefault(const Constant(''))();

  /// Assignment id.
  TextColumn get id => text()();

  TextColumn get rule => text()();

  /// Wire enum strings (`ORDER_COUNT`, `DAILY`, `ACTIVE`, `IN_PROGRESS`) —
  /// stored raw so the cache is a faithful mirror; the repository maps to
  /// domain enums on the way out.
  TextColumn get metric => text()();
  TextColumn get interval => text()();

  RealColumn get targetValue => real()();
  RealColumn get actualValue => real()();

  TextColumn get status => text()();
  BoolColumn get isCurrency => boolean()();

  DateTimeColumn get periodStart => dateTime()();
  DateTimeColumn get periodEnd => dateTime()();

  TextColumn get periodLabel => text()();
  TextColumn get periodStatus => text()();

  /// When this snapshot was fetched — used to prune stale dateKeys.
  DateTimeColumn get fetchedAt => dateTime()();

  /// Composite: the same monthly assignment legitimately appears under
  /// several dateKeys.
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{dateKey, id};
}
