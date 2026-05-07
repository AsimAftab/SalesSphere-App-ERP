import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/sites/data/repositories/sites_repository_impl.dart';
import 'package:sales_sphere_erp/features/sites/domain/repositories/sites_repository.dart';

/// Adds a new category to the site interest catalogue.
class AddInterestCategoryUseCase {
  AddInterestCategoryUseCase(this._repo);

  final SitesRepository _repo;

  Future<void> call(String category) => _repo.addInterestCategory(category);
}

final addInterestCategoryUseCaseProvider =
    Provider<AddInterestCategoryUseCase>((ref) {
  return AddInterestCategoryUseCase(ref.watch(sitesRepositoryProvider));
});
