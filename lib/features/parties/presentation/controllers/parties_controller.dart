import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/domain/usecases/add_party_usecase.dart';
import 'package:sales_sphere_erp/features/parties/domain/usecases/update_party_usecase.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';

part 'parties_controller.g.dart';

/// Routes parties write actions from the UI through the use cases.
/// Reads stay on `partiesListProvider` and `partyByIdProvider`.
///
/// `build()` returns void — the controller has no observable state of
/// its own, it just exposes write methods. Consumers call
/// `ref.read(partiesControllerProvider.notifier).addParty(...)`.
///
/// Marked `keepAlive: true` so the notifier survives across the
/// `await` inside its write methods. Without it, the controller is
/// auto-disposed mid-call (no listeners hold it open) and the
/// follow-up `ref.invalidate(...)` after the await fails because
/// the underlying provider element is already gone.
@Riverpod(keepAlive: true)
class PartiesController extends _$PartiesController {
  @override
  void build() {}

  Future<Party> addParty(Party draft) async {
    final created = await ref.read(addPartyUseCaseProvider)(draft);
    ref.invalidate(partiesListProvider);
    return created;
  }

  Future<Party> updateParty(Party party) async {
    final updated = await ref.read(updatePartyUseCaseProvider)(party);
    ref.invalidate(partiesListProvider);
    return updated;
  }
}
