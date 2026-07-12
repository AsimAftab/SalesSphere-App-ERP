import 'package:drift/drift.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/tables/targets_table.dart';

part 'targets_dao.g.dart';

/// Drift cache for the read-only targets list.
///
/// Deliberately **no `watch*` streams**, unlike `CollectionsDao`: targets have
/// no outbox and no sync handler, so nothing ever writes these rows behind the
/// UI's back — a plain future read on the offline fallback path is sufficient.
/// Don't "fix" this by adding streams without a writer to justify them.
@DriftAccessor(tables: <Type>[Targets])
class TargetsDao extends DatabaseAccessor<AppDatabase> with _$TargetsDaoMixin {
  TargetsDao(super.db);

  /// How long an unrefreshed snapshot stays servable before pruning.
  static const staleAfter = Duration(days: 30);

  /// Wholesale-replace the snapshot for one [dateKey] and prune snapshots
  /// older than [staleAfter]. Replace, never merge: a target unassigned
  /// server-side must disappear from the cache.
  Future<void> replaceForDateKey(
    String dateKey,
    List<TargetsCompanion> rows,
  ) async {
    await transaction(() async {
      await (delete(targets)..where((t) => t.dateKey.equals(dateKey))).go();
      if (rows.isNotEmpty) {
        await batch((b) => b.insertAll(targets, rows));
      }
      final cutoff = DateTime.now().subtract(staleAfter);
      await (delete(targets)..where((t) => t.fetchedAt.isSmallerThanValue(cutoff)))
          .go();
    });
  }

  /// Last-synced rows for one requested date. Empty = never fetched (or
  /// pruned) — the caller should surface the real error, not fabricate data.
  Future<List<TargetRow>> rowsForDateKey(String dateKey) =>
      (select(targets)..where((t) => t.dateKey.equals(dateKey))).get();

  Future<int> deleteAll() => delete(targets).go();
}
