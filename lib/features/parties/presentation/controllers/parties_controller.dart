import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/domain/usecases/add_party_usecase.dart';
import 'package:sales_sphere_erp/features/parties/domain/usecases/update_party_usecase.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';

/// Routes parties write actions from the UI through the use cases.
/// Reads stay on `partiesListProvider` / `partyByIdProvider`.
class PartiesController {
  PartiesController({
    required AddPartyUseCase addParty,
    required UpdatePartyUseCase updateParty,
    required Ref ref,
  })  : _addParty = addParty,
        _updateParty = updateParty,
        _ref = ref;

  final AddPartyUseCase _addParty;
  final UpdatePartyUseCase _updateParty;
  final Ref _ref;

  Future<Party> addParty(Party draft) async {
    final created = await _addParty(draft);
    _ref.invalidate(partiesListProvider);
    return created;
  }

  Future<Party> updateParty(Party party) async {
    final updated = await _updateParty(party);
    _ref.invalidate(partiesListProvider);
    return updated;
  }
}

final partiesControllerProvider = Provider<PartiesController>((ref) {
  return PartiesController(
    addParty: ref.watch(addPartyUseCaseProvider),
    updateParty: ref.watch(updatePartyUseCaseProvider),
    ref: ref,
  );
});
