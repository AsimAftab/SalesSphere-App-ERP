import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/parties/data/repositories/parties_repository_impl.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';

/// Convenience provider for screens that just need the current list.
final partiesListProvider = FutureProvider<List<Party>>((ref) async {
  return ref.watch(partiesRepositoryProvider).getParties();
});

/// Resolves a single party by id from the in-memory store. Watches the
/// list provider so it rebuilds whenever entries are added or updated.
final partyByIdProvider = Provider.family<Party?, String>((ref, id) {
  ref.watch(partiesListProvider);
  return ref.watch(partiesRepositoryProvider).findById(id);
});

/// Catalogue of party types used by the picker. Backed by a mock list in
/// the API today — swap to a real fetch when the backend ships it.
final partyTypesProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(partiesRepositoryProvider).getPartyTypes();
});
