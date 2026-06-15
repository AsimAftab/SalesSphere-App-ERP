import 'package:drift/drift.dart';

/// Local mirror of the active tracking session for a beat plan. **Written
/// exclusively by the background-service isolate** (the GPS/socket runtime) —
/// the UI isolate only reads it (via the service event channel, not drift
/// streams, since two connections to one file don't share stream
/// invalidation). One logical active session per beat plan at a time.
///
/// `id` is the server-issued `sessionId` once `start-tracking` acks; before
/// the ack lands a provisional row may carry a `local_<uuid>` id which is
/// reconciled to the real session id on ack.
@DataClassName('TrackingSessionRow')
class TrackingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get beatPlanId => text()();

  /// `ACTIVE` | `PAUSED` | `COMPLETED`.
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();

  DateTimeColumn get startedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endedAt => dateTime().nullable()();
  DateTimeColumn get lastPingAt => dateTime().nullable()();

  /// Last known fix — drives the notification + live UI dot.
  RealColumn get currentLatitude => real().nullable()();
  RealColumn get currentLongitude => real().nullable()();

  /// Running totals maintained locally between pings for the notification;
  /// the authoritative summary comes back in the `stop-tracking` ack.
  RealColumn get totalDistanceKm => real().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
