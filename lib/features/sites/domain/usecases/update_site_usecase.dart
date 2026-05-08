import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/sites/data/repositories/sites_repository_impl.dart';
import 'package:sales_sphere_erp/features/sites/domain/repositories/sites_repository.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';

/// Updates an existing site. Wraps the repo today; will host conflict
/// resolution + outbox enqueue when the real backend lands.
class UpdateSiteUseCase {
  UpdateSiteUseCase(this._repo);

  final SitesRepository _repo;

  Future<Site> call(Site site) => _repo.updateSite(site);
}

final updateSiteUseCaseProvider = Provider<UpdateSiteUseCase>((ref) {
  return UpdateSiteUseCase(ref.watch(sitesRepositoryProvider));
});
