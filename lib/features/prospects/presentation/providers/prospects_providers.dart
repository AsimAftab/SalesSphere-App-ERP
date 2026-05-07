import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/prospects/data/repositories/prospects_repository_impl.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';

/// Convenience provider for screens that just need the current list.
final prospectsListProvider = FutureProvider<List<Prospect>>((ref) async {
  return ref.watch(prospectsRepositoryProvider).getProspects();
});

/// Resolves a single prospect by id from the in-memory store. Watches the
/// list provider so it rebuilds whenever entries are added or updated.
final prospectByIdProvider = Provider.family<Prospect?, String>((ref, id) {
  ref.watch(prospectsListProvider);
  return ref.watch(prospectsRepositoryProvider).findById(id);
});

/// Catalogue of categories → brands used by the interest picker. Backed
/// by an in-memory map in the API today — swap to a real fetch when the
/// backend ships it.
final prospectInterestsProvider =
    FutureProvider<Map<String, List<String>>>((ref) async {
  return ref.watch(prospectsRepositoryProvider).getInterestCatalogue();
});
