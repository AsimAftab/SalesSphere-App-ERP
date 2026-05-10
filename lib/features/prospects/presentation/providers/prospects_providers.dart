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

/// Resolves a single prospect by id. Derived from the list provider's
/// `AsyncValue` so loading and error states propagate to consumers
/// instead of collapsing into `null`. The previous shape called the
/// repo's synchronous `findById` directly, which couldn't distinguish
/// "still loading" from "actually not found" and made the async
/// `_hydrate` flows on detail pages unreliable.
@riverpod
Future<Prospect?> prospectById(Ref ref, String id) async {
  final prospects = await ref.watch(prospectsListProvider.future);
  for (final prospect in prospects) {
    if (prospect.id == id) return prospect;
  }
  return null;
}

/// Catalogue of categories → brands used by the interest picker.
/// Repository returns the domain `InterestCatalogue`; the raw map
/// shape stays inside `ProspectsApi`.
@riverpod
Future<InterestCatalogue> prospectInterests(Ref ref) async {
  return ref.watch(prospectsRepositoryProvider).getInterestCatalogue();
}
