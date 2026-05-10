import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/prospects/data/dto/prospect_dto.dart';
import 'package:sales_sphere_erp/features/prospects/data/prospects_api.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/features/prospects/domain/repositories/prospects_repository.dart';
import 'package:sales_sphere_erp/shared/domain/interest.dart';
import 'package:sales_sphere_erp/shared/domain/interest_catalogue.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO ↔ domain mapping happens here. Drift persistence + outbox
/// enqueue will land alongside the real API.
class ProspectsRepositoryImpl implements ProspectsRepository {
  ProspectsRepositoryImpl({required ProspectsApi api}) : _api = api;

  final ProspectsApi _api;

  @override
  Future<List<Prospect>> getProspects() async {
    final dtos = await _api.list();
    return dtos.map(_toDomain).toList(growable: false);
  }

  @override
  Future<Prospect> addProspect(Prospect draft) async {
    final created = await _api.create(_toDto(draft));
    return _toDomain(created);
  }

  @override
  Future<Prospect> updateProspect(Prospect prospect) async {
    final updated = await _api.update(_toDto(prospect));
    return _toDomain(updated);
  }

  @override
  Future<InterestCatalogue> getInterestCatalogue() async {
    final raw = await _api.interestCatalogue();
    return InterestCatalogue.fromMap(raw);
  }

  @override
  Future<void> addInterestCategory(String category) =>
      _api.addInterestCategory(category);

  @override
  Future<void> addInterestBrand(String category, String brand) =>
      _api.addInterestBrand(category, brand);

  Prospect _toDomain(ProspectDto dto) => Prospect(
        id: dto.id,
        name: dto.name,
        address: dto.address,
        // DTOs stay nullable for wire compatibility; the domain marks
        // owner + phone non-null because the form's validators require
        // them. Legacy / seed records without these surface as empty
        // strings and the form forces the user to fill them on save.
        ownerName: dto.ownerName ?? '',
        phone: dto.phone ?? '',
        panVat: dto.panVat,
        email: dto.email,
        dateJoined: dto.dateJoined,
        interests: dto.interests
            .map((i) => Interest(category: i.category, brand: i.brand))
            .toList(growable: false),
        notes: dto.notes,
        latitude: dto.latitude,
        longitude: dto.longitude,
        imagePaths: dto.imagePaths,
      );

  ProspectDto _toDto(Prospect p) => ProspectDto(
        // Server assigns the canonical id on create — placeholder here.
        id: p.id,
        name: p.name,
        address: p.address,
        ownerName: p.ownerName,
        panVat: p.panVat,
        phone: p.phone,
        email: p.email,
        dateJoined: p.dateJoined,
        interests: p.interests
            .map((i) =>
                ProspectInterestDto(category: i.category, brand: i.brand))
            .toList(growable: false),
        notes: p.notes,
        latitude: p.latitude,
        longitude: p.longitude,
        imagePaths: p.imagePaths,
      );
}

/// Exposes the abstract type so consumers depend on the contract, not the
/// impl class. Tests override this provider with a fake `ProspectsRepository`.
final prospectsRepositoryProvider = Provider<ProspectsRepository>((ref) {
  return ProspectsRepositoryImpl(api: ref.watch(prospectsApiProvider));
});
