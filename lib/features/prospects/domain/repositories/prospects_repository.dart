import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';

/// Domain-side contract for prospects data. The concrete implementation
/// (DTO mapping, drift persistence, outbox enqueue) lives in
/// `data/repositories/prospects_repository_impl.dart`.
abstract class ProspectsRepository {
  Future<List<Prospect>> getProspects();

  Future<Prospect> addProspect(Prospect draft);

  Future<Prospect> updateProspect(Prospect prospect);

  Prospect? findById(String id);

  Future<Map<String, List<String>>> getInterestCatalogue();

  Future<void> addInterestCategory(String category);

  Future<void> addInterestBrand(String category, String brand);
}
