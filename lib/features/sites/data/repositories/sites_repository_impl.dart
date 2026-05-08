import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/sites/data/dto/site_dto.dart';
import 'package:sales_sphere_erp/features/sites/data/sites_api.dart';
import 'package:sales_sphere_erp/features/sites/domain/repositories/sites_repository.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';
import 'package:sales_sphere_erp/shared/widgets/interest_picker.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO ↔ domain mapping happens here. Drift persistence + outbox
/// enqueue will land alongside the real API.
class SitesRepositoryImpl implements SitesRepository {
  SitesRepositoryImpl({required SitesApi api}) : _api = api;

  final SitesApi _api;

  @override
  Future<List<Site>> getSites() async {
    final dtos = await _api.list();
    return dtos.map(_toDomain).toList(growable: false);
  }

  @override
  Future<Site> addSite(Site draft) async {
    final created = await _api.create(_toDto(draft));
    return _toDomain(created);
  }

  @override
  Future<Site> updateSite(Site site) async {
    final updated = await _api.update(_toDto(site));
    return _toDomain(updated);
  }

  @override
  Site? findById(String id) {
    final dto = _api.findById(id);
    return dto == null ? null : _toDomain(dto);
  }

  @override
  Future<Map<String, List<String>>> getInterestCatalogue() =>
      _api.interestCatalogue();

  @override
  Future<void> addInterestCategory(String category) =>
      _api.addInterestCategory(category);

  @override
  Future<void> addInterestBrand(String category, String brand) =>
      _api.addInterestBrand(category, brand);

  Site _toDomain(SiteDto dto) => Site(
        id: dto.id,
        name: dto.name,
        address: dto.address,
        ownerName: dto.ownerName,
        panVat: dto.panVat,
        phone: dto.phone,
        email: dto.email,
        dateJoined: dto.dateJoined,
        interests: dto.interests
            .map(
              (i) => SiteInterest(
                category: i.category,
                brand: i.brand,
                contacts: i.contacts
                    .map((c) => SiteContact(name: c.name, phone: c.phone))
                    .toList(growable: false),
              ),
            )
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
        panVat: s.panVat,
        phone: s.phone,
        email: s.email,
        dateJoined: s.dateJoined,
        interests: s.interests
            .map(
              (i) => SiteInterestDto(
                category: i.category,
                brand: i.brand,
                contacts: i.contacts
                    .map((c) => SiteContactDto(name: c.name, phone: c.phone))
                    .toList(growable: false),
              ),
            )
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
