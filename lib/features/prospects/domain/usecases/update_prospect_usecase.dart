import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/prospects/data/repositories/prospects_repository_impl.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/features/prospects/domain/repositories/prospects_repository.dart';

/// Updates an existing prospect. Wraps the repo today; will host conflict
/// resolution + outbox enqueue when the real backend lands.
class UpdateProspectUseCase {
  UpdateProspectUseCase(this._repo);

  final ProspectsRepository _repo;

  Future<Prospect> call(Prospect prospect) => _repo.updateProspect(prospect);
}

final updateProspectUseCaseProvider = Provider<UpdateProspectUseCase>((ref) {
  return UpdateProspectUseCase(ref.watch(prospectsRepositoryProvider));
});
