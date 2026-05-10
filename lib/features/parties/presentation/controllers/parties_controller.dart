import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/domain/repositories/parties_repository.dart';
// `parties_providers.dart` re-exports `partiesRepositoryProvider` so
// the controller stays out of `features/.../data/`.
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
      // Insert the new id at the head of `loadedIds` so the row shows up
      // immediately — server's `name asc` ordering can otherwise hide
      // a write past the current page boundary.
      ref.read(partiesListProvider.notifier).prependLocal(created.id);
      return created;
    } on PartialImageUploadException catch (e) {
      // Customer was created; some images didn't upload. Still prepend
      // the row so the list reflects reality, then rethrow so the form
      // can show a partial-success snackbar.
      ref.read(partiesListProvider.notifier).prependLocal(e.party.id);
      rethrow;
    } finally {
      link.close();
    }
  }

  Future<Party> updateParty(Party party) async {
    final link = ref.keepAlive();
    try {
      final updated =
          await ref.read(partiesRepositoryProvider).updateParty(party);
      await ref.read(partiesListProvider.notifier).refresh();
      return updated;
    } finally {
      link.close();
    }
  }
}
