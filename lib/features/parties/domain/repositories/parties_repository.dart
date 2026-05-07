import 'package:sales_sphere_erp/features/parties/domain/party.dart';

/// Domain-side contract for parties data. The concrete implementation
/// (DTO mapping, drift persistence, outbox enqueue) lives in
/// `data/repositories/parties_repository_impl.dart`.
abstract class PartiesRepository {
  Future<List<Party>> getParties();

  Future<Party> addParty(Party draft);

  Future<Party> updateParty(Party party);

  Party? findById(String id);

  Future<List<String>> getPartyTypes();
}
