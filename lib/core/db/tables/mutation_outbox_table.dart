import 'package:drift/drift.dart';

/// Status of a queued mutation as it moves through the sync engine.
enum OutboxStatus { pending, inFlight, succeeded, failed, deadLetter }

/// Conflict-resolution policy for a single mutation. Most field writes are
/// last-write-wins; accounting-touching writes (collections, expense claims)
/// flag [serverAuthoritative] so the backend is the final say.
enum ConflictPolicy { lastWriteWins, serverAuthoritative }

@DataClassName('OutboxEntry')
class MutationOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Logical operation key — used by feature handlers to know how to apply
  /// the result back to local drift tables. e.g. `attendance.checkIn`.
  TextColumn get operation => text()();

  /// HTTP verb, plain string (`POST`, `PATCH`, etc.).
  TextColumn get method => text()();

  /// Endpoint path (relative to API base URL). e.g. `/attendance/check-in`.
  TextColumn get endpoint => text()();

  /// Request body as JSON. Empty string for body-less requests.
  TextColumn get payloadJson => text().withDefault(const Constant(''))();

  /// Optional ID of the local drift row this mutation is updating, so the
  /// repository can reconcile success/failure back to the right record.
  TextColumn get localEntityId => text().nullable()();

  /// Idempotency key sent to backend to dedupe retries. Auto-filled at enqueue
  /// time as a v4 UUID.
  TextColumn get idempotencyKey => text()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get status =>
      textEnum<OutboxStatus>().withDefault(Constant(OutboxStatus.pending.name))();
  TextColumn get conflictPolicy => textEnum<ConflictPolicy>()
      .withDefault(Constant(ConflictPolicy.lastWriteWins.name))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get nextAttemptAt =>
      dateTime().withDefault(currentDateAndTime)();
}
