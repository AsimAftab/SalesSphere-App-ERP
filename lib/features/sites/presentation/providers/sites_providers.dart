import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/sites/data/repositories/sites_repository_impl.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';

/// Convenience provider for screens that just need the current list.
final sitesListProvider = FutureProvider<List<Site>>((ref) async {
  return ref.watch(sitesRepositoryProvider).getSites();
});

/// Resolves a single site by id from the in-memory store. Watches the
/// list provider so it rebuilds whenever entries are added or updated.
final siteByIdProvider = Provider.family<Site?, String>((ref, id) {
  ref.watch(sitesListProvider);
  return ref.watch(sitesRepositoryProvider).findById(id);
});

/// Catalogue of categories → brands used by the interest picker. Backed
/// by an in-memory map in the API today — swap to a real fetch when the
/// backend ships it.
final siteInterestsProvider =
    FutureProvider<Map<String, List<String>>>((ref) async {
  return ref.watch(sitesRepositoryProvider).getInterestCatalogue();
});
