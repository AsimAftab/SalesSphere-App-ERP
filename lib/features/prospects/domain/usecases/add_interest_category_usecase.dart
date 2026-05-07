import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/prospects/data/repositories/prospects_repository_impl.dart';
import 'package:sales_sphere_erp/features/prospects/domain/repositories/prospects_repository.dart';

/// Adds a new category to the interest catalogue.
class AddInterestCategoryUseCase {
  AddInterestCategoryUseCase(this._repo);

  final ProspectsRepository _repo;

  Future<void> call(String category) => _repo.addInterestCategory(category);
}

final addInterestCategoryUseCaseProvider =
    Provider<AddInterestCategoryUseCase>((ref) {
  return AddInterestCategoryUseCase(ref.watch(prospectsRepositoryProvider));
});
