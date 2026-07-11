import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/tables/collections_table.dart';
import 'package:sales_sphere_erp/core/sync/mutation_handler.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';
import 'package:sales_sphere_erp/features/collection_plus/data/repositories/collection_plus_repository_impl.dart';
import 'package:sales_sphere_erp/features/collection_plus/presentation/providers/collection_providers.dart';

/// Bridges the outbox drain back into the Collection Plus drift cache.
///
/// **On 2xx** — swap the `local_<uuid>` row for the server's, *including its
/// allocations*. This is the moment the real split lands: the queued row had
/// none, because the client never computes one. If balances moved while the
/// receipt sat offline, the split that comes back may not be the one the rep
/// previewed — and that's fine, the server is the authority.
///
/// **On dead-letter** — flag the row with the server's own message.
///
/// The dead-letter path is the whole point of `ConflictPolicy.serverAuthoritative`
/// here. Two reps can each record a receipt against the same invoice while
/// offline, both having previewed against a balance that was already stale.
/// Whoever syncs second gets `422 "Selected invoices cover only Rs X. Select
/// more to cover Rs Y."`, the row turns red, and it carries exactly that text.
/// Do **not** silently re-allocate to make it fit — the rep has to know the
/// money didn't land where they thought.
class CollectionPlusSyncHandler implements MutationHandler {
  CollectionPlusSyncHandler(this._ref);

  final Ref _ref;

  @override
  String get operation => kCollectionPlusCreateOperation;

  @override
  Future<void> onSuccess({
    required OutboxEntry entry,
    required Object? responseBody,
  }) async {
    final localId = entry.localEntityId;
    if (localId == null) return;
    if (responseBody is! Map<String, dynamic>) return;
    final inner = responseBody['data'];
    if (inner is! Map<String, dynamic>) return;

    final serverDto = CollectionDto.fromJson(inner);
    await _ref
        .read(collectionsDaoProvider)
        .markSyncSucceeded(localId, CollectionKind.allocated, serverDto);
    _ref
        .read(collectionPlusListProvider.notifier)
        .replaceLocalId(localId, serverDto.id);
  }

  @override
  Future<void> onDeadLetter({
    required OutboxEntry entry,
    required String error,
  }) async {
    final localId = entry.localEntityId;
    if (localId == null) return;
    await _ref.read(collectionsDaoProvider).markSyncFailed(localId, error);
  }
}
