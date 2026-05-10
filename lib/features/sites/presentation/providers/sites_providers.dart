import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/sites/data/repositories/sites_repository_impl.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';
import 'package:sales_sphere_erp/features/sites/domain/sub_organization.dart';
import 'package:sales_sphere_erp/shared/domain/interest_catalogue.dart';

part 'sites_providers.g.dart';

/// Convenience provider for screens that just need the current list.
@riverpod
Future<List<Site>> sitesList(Ref ref) async {
  return ref.watch(sitesRepositoryProvider).getSites();
}

/// Resolves a single site by id. Derived from the list provider's
/// `AsyncValue` so loading and error states propagate to consumers
/// instead of collapsing into `null`.
@riverpod
Future<Site?> siteById(Ref ref, String id) async {
  final sites = await ref.watch(sitesListProvider.future);
  for (final site in sites) {
    if (site.id == id) return site;
  }
  return null;
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
