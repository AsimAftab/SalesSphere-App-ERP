import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/parties/data/repositories/parties_repository_impl.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';

part 'parties_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<Party>> partiesList(Ref ref) async {
  return ref.watch(partiesRepositoryProvider).getParties();
}

/// Resolves a single party by id. Derived from the list provider's
/// `AsyncValue` so loading and error states propagate to consumers
/// instead of collapsing into `null`.
@riverpod
Future<Party?> partyById(Ref ref, String id) async {
  final parties = await ref.watch(partiesListProvider.future);
  for (final party in parties) {
    if (party.id == id) return party;
  }
  return null;
}

/// Catalogue of party types used by the picker. Backed by a mock list in
/// the API today — swap to a real fetch when the backend ships it.
@riverpod
Future<List<String>> partyTypes(Ref ref) async {
  return ref.watch(partiesRepositoryProvider).getPartyTypes();
}
