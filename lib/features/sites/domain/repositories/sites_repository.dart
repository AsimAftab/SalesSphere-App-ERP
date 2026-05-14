import 'package:sales_sphere_erp/features/sites/data/dto/site_image_ref.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';
import 'package:sales_sphere_erp/features/sites/domain/sub_organization.dart';
import 'package:sales_sphere_erp/shared/domain/interest_catalogue.dart';

/// Thrown by [SitesRepository.addSite] when the site was successfully
/// created but at least one attached image upload failed. Carries the
/// created [site] so callers can still reflect the new row in the UI,
/// plus per-slot [failures] keyed by 1-indexed slot number with the
/// backend's error message (or a generic fallback when the response
/// had no shape we recognised).
///
/// Hard failures (the site itself couldn't be created) keep bubbling
/// as the underlying `DioException` — those reach the form's generic
/// catch and leave the user on the page to retry.
class PartialSiteImageUploadException implements Exception {
  const PartialSiteImageUploadException({
    required this.site,
    required this.failures,
  });

  final Site site;
  final Map<int, String> failures;

  /// 1-indexed slot numbers that failed, in deterministic order so the
  /// form's snackbar copy is stable across runs.
  List<int> get failedSlots => failures.keys.toList()..sort();

  /// Convenience for snackbars: the first failure's backend message,
  /// or the generic fallback when there were none.
  String get firstMessage =>
      failures.isEmpty ? 'Upload failed' : failures.values.first;

  @override
  String toString() =>
      'PartialSiteImageUploadException(site=${site.id}, failures=$failures)';
}

/// Domain-side contract for sites data. The concrete implementation
/// (DTO mapping, drift persistence, outbox enqueue) lives in
/// `data/repositories/sites_repository_impl.dart`.
abstract class SitesRepository {
  Future<List<Site>> getSites();

  /// Single-row read for cold-start deep-links. Returns `null` only
  /// when the row genuinely doesn't exist (404) — network errors
  /// propagate so the edit page can show a generic failure state.
  Future<Site?> getSiteById(String id);

  Future<Site> addSite(Site draft);

  Future<Site> updateSite(Site site);

  Future<InterestCatalogue> getInterestCatalogue();

  // Note: no `addInterestCategory` / `addInterestBrand` here. The server
  // auto-upserts unknown categories and brands when they appear inside
  // the `interests` block of `POST /sites` / `PATCH /sites/{id}`. The
  // picker adds the new entry to the user's selection locally; the
  // next write carries it server-side.

  /// Catalogue of sub-organizations (branches / divisions) used by the
  /// add/edit forms.
  Future<List<SubOrganization>> getSubOrganizations();

  /// Fetch the site's current image gallery for the edit form's
  /// picker to hydrate. Returns `[]` for a site with no images.
  Future<List<SiteImageRef>> listImages(String siteId);

  /// Upload (or replace) one image slot.
  Future<void> uploadImage({
    required String siteId,
    required String filePath,
    required int slot,
  });

  /// Delete one image slot.
  Future<void> removeImage({
    required String siteId,
    required int slot,
  });
}
