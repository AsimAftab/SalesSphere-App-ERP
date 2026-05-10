import 'package:drift/drift.dart';

@DataClassName('PartyRow')
class Parties extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get ownerName => text().nullable()();

  /// Wire field is `panNo`; the rest of the mobile codebase calls this
  /// `panVat` (form labels, validators). Translation lives in the
  /// repository's mapper.
  TextColumn get panNo => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get dateJoined => dateTime().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  /// `ACTIVE` | `INACTIVE`. Defaulted so legacy / mock-write rows that omit
  /// the field still satisfy the not-null constraint.
  TextColumn get status =>
      text().withDefault(const Constant('ACTIVE'))();

  /// Flattened name from the wire `customerType: { id, name }` object.
  /// Mobile cares only about the human-readable label; the backend keeps
  /// the FK on its side and auto-upserts on write.
  TextColumn get partyType => text().nullable()();

  /// True while an outbox-queued mutation hasn't yet been confirmed by the
  /// server. The list card surfaces this with an orange `cloud_off` badge.
  /// Reset to false in the sync handler's onSuccess transaction.
  BoolColumn get syncPending =>
      boolean().withDefault(const Constant(false))();

  /// Populated when the sync drain dead-letters this row (4xx, max
  /// retries). The card flips to a red `error_outline` badge while this
  /// is non-null.
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
