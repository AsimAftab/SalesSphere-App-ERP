import 'package:drift/drift.dart';

/// A single stop on a beat plan's route (from `GET /beat-plans/:id`).
/// One [BeatPlans] row owns many of these; the detail page renders them in
/// `sortOrder`. Visit/skip writes optimistically flip [status] + flag
/// [syncPending] while the outbox mutation is in flight, mirroring how
/// `parties` surfaces pending/failed rows.
@DataClassName('BeatPlanStopRow')
class BeatPlanStops extends Table {
  TextColumn get id => text()();
  TextColumn get beatPlanId => text()();

  /// `CUSTOMER` | `SITE` | `PROSPECT` — which directory this stop targets.
  TextColumn get kind => text()();

  /// Ref to the target entity (customer/site/prospect id). Nullable because
  /// the wire shape allows a denormalised stop with no live entity link.
  TextColumn get entityId => text().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// `PENDING` | `VISITED` | `SKIPPED`.
  TextColumn get status => text().withDefault(const Constant('PENDING'))();

  /// Visit timing: `visitedAt` is the END time; `visitStartedAt` is when the
  /// rep tapped "Start"; `visitDurationSec` is server-computed (end − start).
  DateTimeColumn get visitStartedAt => dateTime().nullable()();
  DateTimeColumn get visitedAt => dateTime().nullable()();
  IntColumn get visitDurationSec => integer().nullable()();

  /// Visit proof + outcome.
  TextColumn get visitNotes => text().nullable()();
  DateTimeColumn get followUpDate => dateTime().nullable()();

  /// Cloudinary URL of the single visit-proof photo (slot 1), if uploaded.
  TextColumn get visitImageUrl => text().nullable()();

  RealColumn get visitLatitude => real().nullable()();
  RealColumn get visitLongitude => real().nullable()();

  /// Computed route distance to the next stop, when the backend has run
  /// optimisation. Null until then.
  RealColumn get distanceToNextKm => real().nullable()();

  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
