import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/sites/domain/site.dart';
import 'package:sales_sphere_erp/features/sites/domain/usecases/add_interest_brand_usecase.dart';
import 'package:sales_sphere_erp/features/sites/domain/usecases/add_interest_category_usecase.dart';
import 'package:sales_sphere_erp/features/sites/domain/usecases/add_site_usecase.dart';
import 'package:sales_sphere_erp/features/sites/domain/usecases/update_site_usecase.dart';
import 'package:sales_sphere_erp/features/sites/presentation/providers/sites_providers.dart';

part 'sites_controller.g.dart';

/// Routes sites write actions from the UI through the use cases.
/// Reads stay on `sitesListProvider`, `siteByIdProvider`, and
/// `siteInterestsProvider`.
///
/// `build()` returns void — the controller has no observable state of
/// its own, it just exposes write methods. Consumers call
/// `ref.read(sitesControllerProvider.notifier).addSite(...)`.
///
/// Marked `keepAlive: true` so the notifier survives across the
/// `await` inside its write methods. Without it, the controller is
/// auto-disposed mid-call (no listeners hold it open) and the
/// follow-up `ref.invalidate(...)` after the await fails because
/// the underlying provider element is already gone.
@Riverpod(keepAlive: true)
class SitesController extends _$SitesController {
  @override
  void build() {}

  Future<Site> addSite(Site draft) async {
    final created = await ref.read(addSiteUseCaseProvider)(draft);
    ref.invalidate(sitesListProvider);
    return created;
  }

  Future<Site> updateSite(Site site) async {
    final updated = await ref.read(updateSiteUseCaseProvider)(site);
    ref.invalidate(sitesListProvider);
    return updated;
  }

  Future<void> addInterestCategory(String category) async {
    await ref.read(addInterestCategoryUseCaseProvider)(category);
    ref.invalidate(siteInterestsProvider);
  }

  Future<void> addInterestBrand({
    required String category,
    required String brand,
  }) async {
    await ref.read(addInterestBrandUseCaseProvider)(
      category: category,
      brand: brand,
    );
    ref.invalidate(siteInterestsProvider);
  }
}
