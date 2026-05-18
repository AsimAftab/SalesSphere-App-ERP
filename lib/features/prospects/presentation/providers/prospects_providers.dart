import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/prospects/data/repositories/prospects_repository_impl.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/shared/domain/interest_catalogue.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`. The impl import above stays because this
// file actually uses the provider in its own watch calls.
export 'package:sales_sphere_erp/features/prospects/data/repositories/prospects_repository_impl.dart'
    show prospectsRepositoryProvider;

part 'prospects_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<Prospect>> prospectsList(Ref ref) async {
  return ref.watch(prospectsRepositoryProvider).getProspects();
}

/// Resolves a single prospect by id. Goes through the repository's
/// `getProspectById` so cold-start deep-links work without depending on
/// the list being loaded; the repo handles the 404→null mapping.
@riverpod
Future<Prospect?> prospectById(Ref ref, String id) async {
  return ref.watch(prospectsRepositoryProvider).getProspectById(id);
}

/// Catalogue of categories → brands used by the interest picker.
/// Repository returns the domain `InterestCatalogue`; the raw map
/// shape stays inside `ProspectsApi`.
@riverpod
Future<InterestCatalogue> prospectInterests(Ref ref) async {
  return ref.watch(prospectsRepositoryProvider).getInterestCatalogue();
}
