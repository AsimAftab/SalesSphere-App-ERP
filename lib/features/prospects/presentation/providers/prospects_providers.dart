import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/prospects/data/repositories/prospects_repository_impl.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';

part 'prospects_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<Prospect>> prospectsList(Ref ref) async {
  return ref.watch(prospectsRepositoryProvider).getProspects();
}

/// Resolves a single prospect by id from the in-memory store. Watches
/// the list provider so it rebuilds whenever entries are added or
/// updated.
@riverpod
Prospect? prospectById(Ref ref, String id) {
  ref.watch(prospectsListProvider);
  return ref.watch(prospectsRepositoryProvider).findById(id);
}

/// Catalogue of categories → brands used by the interest picker. Backed
/// by an in-memory map in the API today — swap to a real fetch when the
/// backend ships it.
@riverpod
Future<Map<String, List<String>>> prospectInterests(Ref ref) async {
  return ref.watch(prospectsRepositoryProvider).getInterestCatalogue();
}
