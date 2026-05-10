import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/sync/mutation_handler.dart';
import 'package:sales_sphere_erp/features/parties/data/dto/party_dto.dart';
import 'package:sales_sphere_erp/features/parties/data/repositories/parties_repository_impl.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';

/// Bridges the outbox sync drain back into the parties drift cache and
/// the list notifier's `loadedIds`.
///
/// On 2xx: replace the local-id drift row with the server-issued one and
/// patch the visible list so the rendered row keeps its position.
///
/// On dead-letter: flip the drift row to a "failed" state — the list
/// card surfaces a red badge with the error tooltip.
class PartiesSyncHandler implements MutationHandler {
  PartiesSyncHandler(this._ref);

  final Ref _ref;

  @override
  String get operation => kPartiesCreateOperation;

  @override
  Future<void> onSuccess({
    required OutboxEntry entry,
    required Object? responseBody,
  }) async {
    final localId = entry.localEntityId;
    if (localId == null) return; // defensive — shouldn't happen for parties.
    if (responseBody is! Map<String, dynamic>) return;
    final inner = responseBody['data'];
    if (inner is! Map<String, dynamic>) return;

    final serverDto = PartyDto.fromJson(inner);
    await _ref
        .read(partiesDaoProvider)
        .markSyncSucceeded(localId, serverDto);
    _ref
        .read(partiesListProvider.notifier)
        .replaceLocalId(localId, serverDto.id);
  }

  @override
  Future<void> onDeadLetter({
    required OutboxEntry entry,
    required String error,
  }) async {
    final localId = entry.localEntityId;
    if (localId == null) return;
    await _ref.read(partiesDaoProvider).markSyncFailed(localId, error);
  }
}
