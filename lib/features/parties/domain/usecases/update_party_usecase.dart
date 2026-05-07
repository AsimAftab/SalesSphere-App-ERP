import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/parties/data/repositories/parties_repository_impl.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/domain/repositories/parties_repository.dart';

/// Updates an existing party. Wraps the repo today; will host conflict
/// resolution + outbox enqueue when the real backend lands.
class UpdatePartyUseCase {
  UpdatePartyUseCase(this._repo);

  final PartiesRepository _repo;

  Future<Party> call(Party party) => _repo.updateParty(party);
}

final updatePartyUseCaseProvider = Provider<UpdatePartyUseCase>((ref) {
  return UpdatePartyUseCase(ref.watch(partiesRepositoryProvider));
});
