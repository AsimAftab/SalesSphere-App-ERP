import 'package:sales_sphere_erp/features/sites/domain/site.dart';

/// Domain-side contract for sites data. The concrete implementation
/// (DTO mapping, drift persistence, outbox enqueue) lives in
/// `data/repositories/sites_repository_impl.dart`.
abstract class SitesRepository {
  Future<List<Site>> getSites();

  Future<Site> addSite(Site draft);

  Future<Site> updateSite(Site site);

  Site? findById(String id);

  Future<Map<String, List<String>>> getInterestCatalogue();

  Future<void> addInterestCategory(String category);

  Future<void> addInterestBrand(String category, String brand);
}
