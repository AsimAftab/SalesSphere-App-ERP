import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/parties/data/repositories/parties_repository_impl.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';

part 'parties_controller.g.dart';

/// Routes parties write actions from the UI through the repository.
/// Reads stay on `partiesListProvider` and `partyByIdProvider`.
///
/// Each write method opens a `ref.keepAlive()` link for the duration
/// of its in-flight `await` and closes it in `finally`. That keeps
/// the notifier (and its `ref`) valid through the post-await
/// `ref.invalidate(...)` without permanently pinning a write-only
/// controller in memory.
///
/// The controller now talks to `partiesRepositoryProvider` directly —
/// the trivial passthrough use cases were removed because they only
/// forwarded a single repo call and added no business logic.
@riverpod
class PartiesController extends _$PartiesController {
  @override
  void build() {}

  Future<Party> addParty(Party draft) async {
    final link = ref.keepAlive();
    try {
      final created = await ref.read(partiesRepositoryProvider).addParty(draft);
      ref.invalidate(partiesListProvider);
      return created;
    } finally {
      link.close();
    }
  }

  Future<Party> updateParty(Party party) async {
    final link = ref.keepAlive();
    try {
      final updated =
          await ref.read(partiesRepositoryProvider).updateParty(party);
      ref.invalidate(partiesListProvider);
      return updated;
    } finally {
      link.close();
    }
  }
}
