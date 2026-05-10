import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/sites/data/repositories/sites_repository_impl.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';
import 'package:sales_sphere_erp/features/sites/presentation/providers/sites_providers.dart';

part 'sites_controller.g.dart';

/// Routes sites write actions from the UI through the repository.
/// Reads stay on `sitesListProvider`, `siteByIdProvider`, and
/// `siteInterestsProvider`.
///
/// Each write method opens a `ref.keepAlive()` link for the duration
/// of its in-flight `await` and closes it in `finally`. That keeps
/// the notifier (and its `ref`) valid through the post-await
/// `ref.invalidate(...)` without permanently pinning a write-only
/// controller in memory.
///
/// The controller now talks to `sitesRepositoryProvider` directly —
/// the trivial passthrough use cases were removed because they only
/// forwarded a single repo call and added no business logic.
@riverpod
class SitesController extends _$SitesController {
  @override
  void build() {}

  Future<Site> addSite(Site draft) async {
    final link = ref.keepAlive();
    try {
      final created = await ref.read(sitesRepositoryProvider).addSite(draft);
      ref.invalidate(sitesListProvider);
      return created;
    } finally {
      link.close();
    }
  }

  Future<Site> updateSite(Site site) async {
    final link = ref.keepAlive();
    try {
      final updated = await ref.read(sitesRepositoryProvider).updateSite(site);
      ref.invalidate(sitesListProvider);
      return updated;
    } finally {
      link.close();
    }
  }

  Future<void> addInterestCategory(String category) async {
    final link = ref.keepAlive();
    try {
      await ref.read(sitesRepositoryProvider).addInterestCategory(category);
      ref.invalidate(siteInterestsProvider);
    } finally {
      link.close();
    }
  }

  Future<void> addInterestBrand({
    required String category,
    required String brand,
  }) async {
    final link = ref.keepAlive();
    try {
      await ref
          .read(sitesRepositoryProvider)
          .addInterestBrand(category, brand);
      ref.invalidate(siteInterestsProvider);
    } finally {
      link.close();
    }
  }
}
