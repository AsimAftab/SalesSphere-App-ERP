import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/prospects/data/repositories/prospects_repository_impl.dart';
import 'package:sales_sphere_erp/features/prospects/domain/repositories/prospects_repository.dart';

/// Adds a brand under an existing category in the interest catalogue.
class AddInterestBrandUseCase {
  AddInterestBrandUseCase(this._repo);

  final ProspectsRepository _repo;

  Future<void> call({required String category, required String brand}) =>
      _repo.addInterestBrand(category, brand);
}

final addInterestBrandUseCaseProvider =
    Provider<AddInterestBrandUseCase>((ref) {
  return AddInterestBrandUseCase(ref.watch(prospectsRepositoryProvider));
});
