import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/sync/mutation_handler.dart';

/// Reconciles a queued `beat_plan.visit` / `beat_plan.skip` write back into the
/// beat-plan drift cache. One instance is registered per operation key.
///
/// On 2xx: clear the stop's `syncPending` flag (the optimistic status already
/// applied at enqueue time stands). On dead-letter: flag the stop failed so
/// the route card surfaces a red badge with the error.
class BeatPlanStopSyncHandler implements MutationHandler {
  BeatPlanStopSyncHandler(this._ref, this._operation);

  final Ref _ref;
  final String _operation;

  @override
  String get operation => _operation;

  @override
  Future<void> onSuccess({
    required OutboxEntry entry,
    required Object? responseBody,
  }) async {
    final stopId = entry.localEntityId;
    if (stopId == null) return;
    await _ref.read(beatPlanDaoProvider).markStopSyncSucceeded(stopId);
  }

  @override
  Future<void> onDeadLetter({
    required OutboxEntry entry,
    required String error,
  }) async {
    final stopId = entry.localEntityId;
    if (stopId == null) return;
    await _ref.read(beatPlanDaoProvider).markStopSyncFailed(stopId, error);
  }
}
