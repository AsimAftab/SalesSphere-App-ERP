import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/sites/data/repositories/sites_repository_impl.dart';
import 'package:sales_sphere_erp/features/sites/domain/repositories/sites_repository.dart';

/// Adds a brand under an existing category in the site interest catalogue.
class AddInterestBrandUseCase {
  AddInterestBrandUseCase(this._repo);

  final SitesRepository _repo;

  Future<void> call({required String category, required String brand}) =>
      _repo.addInterestBrand(category, brand);
}

final addInterestBrandUseCaseProvider =
    Provider<AddInterestBrandUseCase>((ref) {
  return AddInterestBrandUseCase(ref.watch(sitesRepositoryProvider));
});
