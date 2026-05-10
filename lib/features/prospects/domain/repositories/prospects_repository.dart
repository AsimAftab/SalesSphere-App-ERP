import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/shared/domain/interest_catalogue.dart';

/// Domain-side contract for prospects data. The concrete implementation
/// (DTO mapping, drift persistence, outbox enqueue) lives in
/// `data/repositories/prospects_repository_impl.dart`.
abstract class ProspectsRepository {
  Future<List<Prospect>> getProspects();

  Future<Prospect> addProspect(Prospect draft);

  Future<Prospect> updateProspect(Prospect prospect);

  Future<InterestCatalogue> getInterestCatalogue();

  Future<void> addInterestCategory(String category);

  Future<void> addInterestBrand(String category, String brand);
}
