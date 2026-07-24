import 'package:drift/drift.dart';
import 'package:sales_sphere_erp/core/db/tables/beat_plan_stops_table.dart' show BeatPlanStops;

/// Local mirror of a beat plan from `GET /beat-plans` (+ `/beat-plans/:id`).
/// UI reads come from here so the route list works offline; the repository
/// upserts every fetch. Progress counters are denormalised exactly as the
/// backend sends them so the UI never has to re-derive them from stops.
///
/// `syncPending` / `syncError` mirror the parties pattern: an optimistic
/// visit/skip write flags the plan's affected stop, not the plan itself, so
/// these columns stay on [BeatPlanStops]. They live here too for symmetry and
/// future plan-level offline writes (e.g. local `start`).
@DataClassName('BeatPlanRow')
class BeatPlans extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// `PENDING` | `ACTIVE` | `COMPLETED`.
  TextColumn get status => text().withDefault(const Constant('PENDING'))();

  /// `DAILY` | `WEEKLY` | `MONTHLY` | `CUSTOM`.
  TextColumn get frequency => text().withDefault(const Constant('CUSTOM'))();

  /// Org-TZ start-of-day UTC the plan is scheduled for. Drives the
  /// "scheduled for today" gate the backend enforces on `start`.
  DateTimeColumn get scheduledDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  IntColumn get totalStops => integer().withDefault(const Constant(0))();
  IntColumn get visitedStops => integer().withDefault(const Constant(0))();
  IntColumn get skippedStops => integer().withDefault(const Constant(0))();

  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
