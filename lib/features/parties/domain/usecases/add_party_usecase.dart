import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/parties/data/repositories/parties_repository_impl.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/domain/repositories/parties_repository.dart';

/// Creates a new party. Wraps the repo today; will host validation +
/// outbox enqueue when the real backend lands.
class AddPartyUseCase {
  AddPartyUseCase(this._repo);

  final PartiesRepository _repo;

  Future<Party> call(Party draft) => _repo.addParty(draft);
}

final addPartyUseCaseProvider = Provider<AddPartyUseCase>((ref) {
  return AddPartyUseCase(ref.watch(partiesRepositoryProvider));
});
