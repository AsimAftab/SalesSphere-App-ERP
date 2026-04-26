import 'package:sales_sphere_erp/core/db/app_database.dart';

/// Per-feature handler invoked by [SyncService] when an outbox mutation comes
/// back successfully. Each feature registers a handler keyed by its
/// [OutboxEntry.operation] so the response can be reconciled into the right
/// drift tables. Handlers must be idempotent.
abstract class MutationHandler {
  String get operation;

  /// Called after the HTTP request returns 2xx. [responseBody] is the parsed
  /// JSON response (Map or List), or null for body-less responses.
  Future<void> onSuccess({
    required OutboxEntry entry,
    required Object? responseBody,
  });

  /// Called when the mutation has exceeded retry budget and is dead-lettered.
  /// Default: no-op. Features can override to flag a "needs review" state on
  /// the local entity.
  Future<void> onDeadLetter({
    required OutboxEntry entry,
    required String error,
  }) async {}
}
