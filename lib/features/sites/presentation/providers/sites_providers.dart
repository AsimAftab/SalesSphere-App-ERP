import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/sites/data/repositories/sites_repository_impl.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';
import 'package:sales_sphere_erp/features/sites/domain/sub_organization.dart';
import 'package:sales_sphere_erp/shared/domain/interest_catalogue.dart';

// Re-export the repository provider so downstream consumers
// (controllers, tests) can depend on the contract surface without
// importing from `data/`. The impl import above stays because this
// file actually uses the provider in its own watch calls.
export 'package:sales_sphere_erp/features/sites/data/repositories/sites_repository_impl.dart'
    show sitesRepositoryProvider;

part 'sites_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<Site>> sitesList(Ref ref) async {
  return ref.watch(sitesRepositoryProvider).getSites();
}

/// Resolves a single site by id straight from the repository (which
/// hits `GET /sites/{id}`). Decoupled from the list provider so deep
/// links don't block on a list fetch they don't need, and the detail
/// page doesn't re-run every time the list is invalidated. Returns
/// `null` only when the row genuinely doesn't exist (404).
@riverpod
Future<Site?> siteById(Ref ref, String id) async {
  return ref.read(sitesRepositoryProvider).getSiteById(id);
}

/// Catalogue of categories → brands used by the interest picker.
/// Repository returns the domain `InterestCatalogue`; the raw map
/// shape stays inside `SitesApi`.
@riverpod
Future<InterestCatalogue> siteInterests(Ref ref) async {
  return ref.watch(sitesRepositoryProvider).getInterestCatalogue();
}

/// Sub-organizations (branches / divisions) shown in the dropdown on
/// the add / edit site forms. Backed by an in-memory list today —
/// swaps to a real fetch when the backend exposes the endpoint.
@riverpod
Future<List<SubOrganization>> siteSubOrganizations(Ref ref) async {
  return ref.watch(sitesRepositoryProvider).getSubOrganizations();
}
