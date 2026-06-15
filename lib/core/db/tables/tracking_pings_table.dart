import 'package:drift/drift.dart';

/// The **GPS ping outbox** — the durable buffer that makes live tracking
/// offline-safe. Every fix is written here (with a client-minted
/// [clientPingId]) **before** it's emitted over the socket; the row is
/// deleted only once the server acks it. On reconnect the background isolate
/// flushes everything still here via `update-location-batch` (the server
/// dedupes on `(session, clientPingId)`, so over-sending is safe).
///
/// This is a **separate mechanism from `mutation_outbox`**: that one drains
/// REST writes via Dio on the UI isolate; this one is drained over the socket
/// by the background isolate. Keeping them disjoint preserves the
/// single-writer-per-table discipline across the two isolates.
///
/// Rows present == not-yet-confirmed. There is no status column: a confirmed
/// ping is deleted. Concurrent re-send races (a live emit overlapping a batch
/// flush) are harmless because the server is idempotent on [clientPingId].
@DataClassName('TrackingPingRow')
class TrackingPings extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Client-minted v4 UUID, stable across retries — the server's idempotency
  /// key. Never regenerated once assigned at fix time.
  TextColumn get clientPingId => text().unique()();

  TextColumn get beatPlanId => text()();

  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real().nullable()();
  RealColumn get speed => real().nullable()();
  RealColumn get heading => real().nullable()();

  /// Capture time on the device clock, so a ping flushed minutes late still
  /// carries its true time, not the flush time.
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get address => text().nullable()();

  /// Device battery percentage (0–100) at capture time. Stored on the row so a
  /// batch-flushed buffered ping replays its real reading, not the latest.
  IntColumn get batteryLevel => integer().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
