import 'package:drift/drift.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/tables/mutation_outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: <Type>[MutationOutbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// FIFO drain query — returns up to [limit] rows that are ready to ship.
  Future<List<OutboxEntry>> nextBatch({int limit = 20}) {
    final now = DateTime.now();
    return (select(mutationOutbox)
          ..where(
            (o) =>
                o.status.equalsValue(OutboxStatus.pending) &
                o.nextAttemptAt.isSmallerOrEqualValue(now),
          )
          ..orderBy(<OrderingTerm Function(MutationOutbox)>[
            (o) => OrderingTerm(expression: o.createdAt),
          ])
          ..limit(limit))
        .get();
  }

  Stream<int> watchPendingCount() {
    return (selectOnly(mutationOutbox)
          ..addColumns(<Expression<Object>>[mutationOutbox.id.count()])
          ..where(mutationOutbox.status.equalsValue(OutboxStatus.pending)))
        .map((row) => row.read(mutationOutbox.id.count()) ?? 0)
        .watchSingle();
  }

  Future<int> enqueue(MutationOutboxCompanion entry) {
    return into(mutationOutbox).insert(entry);
  }

  Future<bool> markInFlight(int id) {
    return (update(mutationOutbox)..where((o) => o.id.equals(id)))
        .write(
          MutationOutboxCompanion(
            status: Value(OutboxStatus.inFlight),
          ),
        )
        .then((rows) => rows > 0);
  }

  Future<bool> markSucceeded(int id) {
    return (update(mutationOutbox)..where((o) => o.id.equals(id)))
        .write(
          MutationOutboxCompanion(
            status: Value(OutboxStatus.succeeded),
            lastError: const Value(null),
          ),
        )
        .then((rows) => rows > 0);
  }

  Future<bool> markFailed(int id, String error, DateTime nextAttempt) {
    return (update(mutationOutbox)..where((o) => o.id.equals(id)))
        .write(
          MutationOutboxCompanion(
            status: const Value(OutboxStatus.pending),
            lastError: Value(error),
            attempts: const Value.absent(),
            nextAttemptAt: Value(nextAttempt),
          ),
        )
        .then((rows) => rows > 0);
  }

  Future<bool> markDeadLetter(int id, String error) {
    return (update(mutationOutbox)..where((o) => o.id.equals(id)))
        .write(
          MutationOutboxCompanion(
            status: const Value(OutboxStatus.deadLetter),
            lastError: Value(error),
          ),
        )
        .then((rows) => rows > 0);
  }

  Future<int> deleteSucceeded() {
    return (delete(mutationOutbox)
          ..where((o) => o.status.equalsValue(OutboxStatus.succeeded)))
        .go();
  }
}
