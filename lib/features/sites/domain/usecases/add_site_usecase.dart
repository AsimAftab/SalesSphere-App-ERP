import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/sites/data/repositories/sites_repository_impl.dart';
import 'package:sales_sphere_erp/features/sites/domain/repositories/sites_repository.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';

/// Creates a new site. Wraps the repo today; will host validation +
/// outbox enqueue when the real backend lands.
class AddSiteUseCase {
  AddSiteUseCase(this._repo);

  final SitesRepository _repo;

  Future<Site> call(Site draft) => _repo.addSite(draft);
}

final addSiteUseCaseProvider = Provider<AddSiteUseCase>((ref) {
  return AddSiteUseCase(ref.watch(sitesRepositoryProvider));
});
