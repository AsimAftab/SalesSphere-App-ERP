import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/prospects/data/repositories/prospects_repository_impl.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/features/prospects/domain/repositories/prospects_repository.dart';

/// Creates a new prospect. Wraps the repo today; will host validation +
/// outbox enqueue when the real backend lands.
class AddProspectUseCase {
  AddProspectUseCase(this._repo);

  final ProspectsRepository _repo;

  Future<Prospect> call(Prospect draft) => _repo.addProspect(draft);
}

final addProspectUseCaseProvider = Provider<AddProspectUseCase>((ref) {
  return AddProspectUseCase(ref.watch(prospectsRepositoryProvider));
});
