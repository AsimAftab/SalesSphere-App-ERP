import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/parties/data/repositories/parties_repository_impl.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';

part 'parties_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<Party>> partiesList(Ref ref) async {
  return ref.watch(partiesRepositoryProvider).getParties();
}

/// Resolves a single party by id from the in-memory store. Watches the
/// list provider so it rebuilds whenever entries are added or updated.
@riverpod
Party? partyById(Ref ref, String id) {
  ref.watch(partiesListProvider);
  return ref.watch(partiesRepositoryProvider).findById(id);
}

/// Catalogue of party types used by the picker. Backed by a mock list in
/// the API today — swap to a real fetch when the backend ships it.
@riverpod
Future<List<String>> partyTypes(Ref ref) async {
  return ref.watch(partiesRepositoryProvider).getPartyTypes();
}
