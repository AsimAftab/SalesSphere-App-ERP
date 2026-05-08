import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/sites/domain/site.dart';
import 'package:sales_sphere_erp/features/sites/domain/usecases/add_interest_brand_usecase.dart';
import 'package:sales_sphere_erp/features/sites/domain/usecases/add_interest_category_usecase.dart';
import 'package:sales_sphere_erp/features/sites/domain/usecases/add_site_usecase.dart';
import 'package:sales_sphere_erp/features/sites/domain/usecases/update_site_usecase.dart';
import 'package:sales_sphere_erp/features/sites/presentation/providers/sites_providers.dart';

/// Routes sites write actions from the UI through the use cases.
/// Reads stay on `sitesListProvider`, `siteByIdProvider`, and
/// `siteInterestsProvider`.
class SitesController {
  SitesController({
    required AddSiteUseCase addSite,
    required UpdateSiteUseCase updateSite,
    required AddInterestCategoryUseCase addInterestCategory,
    required AddInterestBrandUseCase addInterestBrand,
    required Ref ref,
  })  : _addSite = addSite,
        _updateSite = updateSite,
        _addInterestCategory = addInterestCategory,
        _addInterestBrand = addInterestBrand,
        _ref = ref;

  final AddSiteUseCase _addSite;
  final UpdateSiteUseCase _updateSite;
  final AddInterestCategoryUseCase _addInterestCategory;
  final AddInterestBrandUseCase _addInterestBrand;
  final Ref _ref;

  Future<Site> addSite(Site draft) async {
    final created = await _addSite(draft);
    _ref.invalidate(sitesListProvider);
    return created;
  }

  Future<Site> updateSite(Site site) async {
    final updated = await _updateSite(site);
    _ref.invalidate(sitesListProvider);
    return updated;
  }

  Future<void> addInterestCategory(String category) async {
    await _addInterestCategory(category);
    _ref.invalidate(siteInterestsProvider);
  }

  Future<void> addInterestBrand({
    required String category,
    required String brand,
  }) async {
    await _addInterestBrand(category: category, brand: brand);
    _ref.invalidate(siteInterestsProvider);
  }
}

final sitesControllerProvider = Provider<SitesController>((ref) {
  return SitesController(
    addSite: ref.watch(addSiteUseCaseProvider),
    updateSite: ref.watch(updateSiteUseCaseProvider),
    addInterestCategory: ref.watch(addInterestCategoryUseCaseProvider),
    addInterestBrand: ref.watch(addInterestBrandUseCaseProvider),
    ref: ref,
  );
});
