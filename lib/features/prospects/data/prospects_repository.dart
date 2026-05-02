import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/prospects/data/dto/prospect_dto.dart';
import 'package:sales_sphere_erp/features/prospects/data/prospects_api.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/shared/widgets/interest_picker.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO → domain mapping happens here. Drift persistence + outbox
/// enqueue will land alongside the real API.
class ProspectsRepository {
  ProspectsRepository({required ProspectsApi api}) : _api = api;

  final ProspectsApi _api;

  Future<List<Prospect>> getProspects() async {
    final dtos = await _api.list();
    return dtos.map(_toDomain).toList(growable: false);
  }

  Future<Prospect> addProspect(Prospect draft) async {
    final created = await _api.create(_toDto(draft));
    return _toDomain(created);
  }

  Future<Prospect> updateProspect(Prospect prospect) async {
    final updated = await _api.update(_toDto(prospect));
    return _toDomain(updated);
  }

  Prospect? findById(String id) {
    final dto = _api.findById(id);
    return dto == null ? null : _toDomain(dto);
  }

  Future<Map<String, List<String>>> getInterestCatalogue() =>
      _api.interestCatalogue();

  Future<void> addInterestCategory(String category) =>
      _api.addInterestCategory(category);

  Future<void> addInterestBrand(String category, String brand) =>
      _api.addInterestBrand(category, brand);

  Prospect _toDomain(ProspectDto dto) => Prospect(
        id: dto.id,
        name: dto.name,
        address: dto.address,
        ownerName: dto.ownerName,
        panVat: dto.panVat,
        phone: dto.phone,
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

final prospectsRepositoryProvider = Provider<ProspectsRepository>((ref) {
  return ProspectsRepository(api: ref.watch(prospectsApiProvider));
});

/// Convenience provider for screens that just need the current list.
final prospectsListProvider = FutureProvider<List<Prospect>>((ref) async {
  return ref.watch(prospectsRepositoryProvider).getProspects();
});

/// Resolves a single prospect by id from the in-memory store. Watches
/// the list provider so it rebuilds whenever the list changes
/// (add / update).
final prospectByIdProvider = Provider.family<Prospect?, String>((ref, id) {
  // Touch the list so rebuilds propagate when entries are added or updated.
  ref.watch(prospectsListProvider);
  return ref.watch(prospectsRepositoryProvider).findById(id);
});

/// Catalogue of categories → brands used by the interest picker. Backed
/// by an in-memory map in the API today — swap to a real fetch when the
/// backend ships it.
final prospectInterestsProvider =
    FutureProvider<Map<String, List<String>>>((ref) async {
  return ref.watch(prospectsRepositoryProvider).getInterestCatalogue();
});
