import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/sites/data/repositories/sites_repository_impl.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';

part 'sites_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<Site>> sitesList(Ref ref) async {
  return ref.watch(sitesRepositoryProvider).getSites();
}

/// Resolves a single site by id from the in-memory store. Watches the
/// list provider so it rebuilds whenever entries are added or updated.
@riverpod
Site? siteById(Ref ref, String id) {
  ref.watch(sitesListProvider);
  return ref.watch(sitesRepositoryProvider).findById(id);
}

/// Catalogue of categories → brands used by the interest picker. Backed
/// by an in-memory map in the API today — swap to a real fetch when the
/// backend ships it.
@riverpod
Future<Map<String, List<String>>> siteInterests(Ref ref) async {
  return ref.watch(sitesRepositoryProvider).getInterestCatalogue();
}
