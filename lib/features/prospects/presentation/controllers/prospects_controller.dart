import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/features/prospects/domain/usecases/add_interest_brand_usecase.dart';
import 'package:sales_sphere_erp/features/prospects/domain/usecases/add_interest_category_usecase.dart';
import 'package:sales_sphere_erp/features/prospects/domain/usecases/add_prospect_usecase.dart';
import 'package:sales_sphere_erp/features/prospects/domain/usecases/update_prospect_usecase.dart';
import 'package:sales_sphere_erp/features/prospects/presentation/providers/prospects_providers.dart';

/// Routes prospects write actions from the UI through the use cases.
/// Reads stay on `prospectsListProvider`, `prospectByIdProvider`, and
/// `prospectInterestsProvider`.
class ProspectsController {
  ProspectsController({
    required AddProspectUseCase addProspect,
    required UpdateProspectUseCase updateProspect,
    required AddInterestCategoryUseCase addInterestCategory,
    required AddInterestBrandUseCase addInterestBrand,
    required Ref ref,
  })  : _addProspect = addProspect,
        _updateProspect = updateProspect,
        _addInterestCategory = addInterestCategory,
        _addInterestBrand = addInterestBrand,
        _ref = ref;

  final AddProspectUseCase _addProspect;
  final UpdateProspectUseCase _updateProspect;
  final AddInterestCategoryUseCase _addInterestCategory;
  final AddInterestBrandUseCase _addInterestBrand;
  final Ref _ref;

  Future<Prospect> addProspect(Prospect draft) async {
    final created = await _addProspect(draft);
    _ref.invalidate(prospectsListProvider);
    return created;
  }

  Future<Prospect> updateProspect(Prospect prospect) async {
    final updated = await _updateProspect(prospect);
    _ref.invalidate(prospectsListProvider);
    return updated;
  }

  Future<void> addInterestCategory(String category) async {
    await _addInterestCategory(category);
    _ref.invalidate(prospectInterestsProvider);
  }

  Future<void> addInterestBrand({
    required String category,
    required String brand,
  }) async {
    await _addInterestBrand(category: category, brand: brand);
    _ref.invalidate(prospectInterestsProvider);
  }
}

final prospectsControllerProvider = Provider<ProspectsController>((ref) {
  return ProspectsController(
    addProspect: ref.watch(addProspectUseCaseProvider),
    updateProspect: ref.watch(updateProspectUseCaseProvider),
    addInterestCategory: ref.watch(addInterestCategoryUseCaseProvider),
    addInterestBrand: ref.watch(addInterestBrandUseCaseProvider),
    ref: ref,
  );
});
