import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/tables/collections_table.dart';
import 'package:sales_sphere_erp/core/sync/mutation_handler.dart';
import 'package:sales_sphere_erp/features/collection/data/dto/collection_dto.dart';
import 'package:sales_sphere_erp/features/collection/data/repositories/collection_repository_impl.dart';
import 'package:sales_sphere_erp/features/collection/presentation/providers/collection_providers.dart';

/// Bridges the outbox drain back into the collections drift cache and the
/// list notifier's `loadedIds`.
///
/// **On 2xx** — replace the `local_<uuid>` row with the server-issued one and
/// patch the visible list so the rendered row keeps its position. The response
/// is the full collection either way: `201` for a fresh create, `200` when the
/// server recognised the `clientRequestId` and returned the row it already
/// had. We don't care which — the row is the row.
///
/// **On dead-letter** — flag the drift row with the server's own message. The
/// card flips from an orange "pending" badge to a red one carrying the reason.
///
/// That red badge *is* the server-authoritative rejection surface. A
/// Collection Plus receipt allocated offline against a balance that has since
/// moved comes back `422 "Selected invoices cover only Rs X…"`, and the rep
/// sees exactly that. Do not silently re-allocate to make it fit — the whole
/// point is that the server won.
class CollectionSyncHandler implements MutationHandler {
  CollectionSyncHandler(this._ref);

  final Ref _ref;

  @override
  String get operation => kCollectionCreateOperation;

  @override
  Future<void> onSuccess({
    required OutboxEntry entry,
    required Object? responseBody,
  }) async {
    final localId = entry.localEntityId;
    if (localId == null) return; // defensive — always set for collections.
    if (responseBody is! Map<String, dynamic>) return;
    final inner = responseBody['data'];
    if (inner is! Map<String, dynamic>) return;

    final serverDto = CollectionDto.fromJson(inner);
    await _ref
        .read(collectionsDaoProvider)
        .markSyncSucceeded(localId, CollectionKind.onAccount, serverDto);
    _ref
        .read(collectionListProvider.notifier)
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
