import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/sites/data/dto/site_dto.dart';
import 'package:sales_sphere_erp/features/sites/data/dto/site_image_ref.dart';
import 'package:sales_sphere_erp/features/sites/data/sites_api.dart';
import 'package:sales_sphere_erp/features/sites/domain/repositories/sites_repository.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';
import 'package:sales_sphere_erp/features/sites/domain/site_contact.dart';
import 'package:sales_sphere_erp/features/sites/domain/sub_organization.dart';
import 'package:sales_sphere_erp/shared/domain/interest.dart';
import 'package:sales_sphere_erp/shared/domain/interest_catalogue.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO ↔ domain mapping happens here.
///
/// Drift cache + outbox are not wired for sites yet (parties owns the
/// offline-first plumbing). Cold-start deep-links to a single site
/// always hit the network; mutations don't queue. This gap is tracked
/// against the "wire `POST /sites` + drift" follow-up.
class SitesRepositoryImpl implements SitesRepository {
  SitesRepositoryImpl({required SitesApi api}) : _api = api;

  final SitesApi _api;

  @override
  Future<List<Site>> getSites() async {
    final dtos = await _api.list();
    return dtos.map(_toDomain).toList(growable: false);
  }

  @override
  Future<Site?> getSiteById(String id) async {
    // TODO(sites): no drift cache yet — every cold-start deep-link hits
    // the network. Wire drift + outbox alongside POST /sites in a
    // follow-up so this can fall back to the local cache first.
    try {
      final dto = await _api.getById(id);
      return _toDomain(dto);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Site> addSite(Site draft) async {
    final created = await _api.create(_toDto(draft));
    // Mirror parties: best-effort image upload after a successful
    // create. Each local file goes to slot i+1; per-slot failures are
    // collected and surfaced via [PartialSiteImageUploadException] so
    // the add page can show a useful snackbar (and still pop back —
    // the user has a row to edit and can retry the missing slots).
    final failures = <int, String>{};
    for (var i = 0; i < draft.imagePaths.length; i++) {
      try {
        await _api.uploadImage(
          siteId: created.id,
          filePath: draft.imagePaths[i],
          imageNumber: i + 1,
        );
      } on DioException catch (e) {
        failures[i + 1] = extractBackendErrorMessage(e) ?? 'Upload failed';
      }
    }
    final domain = _toDomain(created);
    if (failures.isNotEmpty) {
      throw PartialSiteImageUploadException(site: domain, failures: failures);
    }
    return domain;
  }

  @override
  Future<Site> updateSite(Site site) async {
    final updated = await _api.update(_toDto(site));
    return _toDomain(updated);
  }

  @override
  Future<InterestCatalogue> getInterestCatalogue() async {
    final raw = await _api.interestCatalogue();
    return InterestCatalogue.fromMap(raw);
  }

  @override
  Future<List<SubOrganization>> getSubOrganizations() async {
    final dtos = await _api.subOrganizations();
    return dtos
        .map((d) => SubOrganization(id: d.id, name: d.name))
        .toList(growable: false);
  }

  @override
  Future<List<SiteImageRef>> listImages(String siteId) =>
      _api.listImages(siteId);

  @override
  Future<void> uploadImage({
    required String siteId,
    required String filePath,
    required int slot,
  }) =>
      _api.uploadImage(
        siteId: siteId,
        filePath: filePath,
        imageNumber: slot,
      );

  @override
  Future<void> removeImage({
    required String siteId,
    required int slot,
  }) =>
      _api.removeImage(siteId: siteId, imageNumber: slot);

  Site _toDomain(SiteDto dto) => Site(
        id: dto.id,
        name: dto.name,
        address: dto.address,
        // DTOs stay nullable for wire compatibility; the domain marks
        // owner + phone non-null because the form's validators require
        // them. Legacy / seed records without these surface as empty
        // strings and the form forces the user to fill them on save.
        ownerName: dto.ownerName ?? '',
        phone: dto.phone ?? '',
        subOrganizationId: dto.subOrganizationId,
        subOrganizationName: dto.subOrganizationName,
        email: dto.email,
        dateJoined: dto.dateJoined,
        interests: dto.interests
            .map((i) => Interest(category: i.category, brand: i.brand))
            .toList(growable: false),
        contacts: dto.contacts
            .map((c) => SiteContact(name: c.name, phone: c.phone))
            .toList(growable: false),
        notes: dto.notes,
        latitude: dto.latitude,
        longitude: dto.longitude,
        imagePaths: dto.imagePaths,
      );

  SiteDto _toDto(Site s) => SiteDto(
        // Server assigns the canonical id on create — placeholder here.
        id: s.id,
        name: s.name,
        address: s.address,
        ownerName: s.ownerName,
        subOrganizationId: s.subOrganizationId,
        subOrganizationName: s.subOrganizationName,
        phone: s.phone,
        email: s.email,
        dateJoined: s.dateJoined,
        interests: s.interests
            .map((i) => SiteInterestDto(category: i.category, brand: i.brand))
            .toList(growable: false),
        contacts: s.contacts
            .map((c) => SiteContactDto(name: c.name, phone: c.phone))
            .toList(growable: false),
        notes: s.notes,
        latitude: s.latitude,
        longitude: s.longitude,
        imagePaths: s.imagePaths,
      );
}

/// Exposes the abstract type so consumers depend on the contract, not the
/// impl class. Tests override this provider with a fake `SitesRepository`.
final sitesRepositoryProvider = Provider<SitesRepository>((ref) {
  return SitesRepositoryImpl(api: ref.watch(sitesApiProvider));
});
