import 'package:drift/drift.dart';

/// Completed-session summary, persisted for the history view. Written by the
/// UI isolate from the `stop-tracking` / `tracking-force-stopped` payload the
/// background service hands over (keeping the bg isolate out of this table so
/// the single-writer rule holds).
@DataClassName('TrackingSummaryRow')
class TrackingSummaries extends Table {
  TextColumn get sessionId => text()();
  TextColumn get beatPlanId => text()();

  RealColumn get totalDistanceKm => real().withDefault(const Constant(0))();
  IntColumn get totalDurationMin => integer().withDefault(const Constant(0))();
  RealColumn get averageSpeedKmh => real().withDefault(const Constant(0))();
  IntColumn get directoriesVisited =>
      integer().withDefault(const Constant(0))();

  DateTimeColumn get completedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Why the session ended, when it wasn't a plain rep-driven stop:
  /// `beat_plan_completed` | `force_completed` | `attendance_checkout` |
  /// `stale_timeout`. Null for a normal stop.
  TextColumn get reason => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{sessionId};
}
