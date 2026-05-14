import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/sites/domain/site.dart';
// `sites_providers.dart` re-exports `sitesRepositoryProvider` so the
// controller stays out of `features/.../data/`.
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

  // Note: no separate `addInterestCategory` / `addInterestBrand` here.
  // The server auto-upserts unknown categories and brands when they
  // arrive inside `interests` on `POST /sites` or `PATCH /sites/{id}`.
  // The picker's "add new" dialogs update the user's selection locally
  // (and the in-sheet catalogue copy); the next save carries them
  // through and the next catalogue fetch reflects them.
}
