import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/parties/data/dto/party_dto.dart';
import 'package:sales_sphere_erp/features/parties/data/parties_api.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO → domain mapping happens here. Drift persistence + outbox
/// enqueue will land alongside the real API.
class PartiesRepository {
  PartiesRepository({required PartiesApi api}) : _api = api;

  final PartiesApi _api;

  Future<List<Party>> getParties() async {
    final dtos = await _api.list();
    return dtos.map(_toDomain).toList(growable: false);
  }

  Future<Party> addParty(Party draft) async {
    final created = await _api.create(_toDto(draft));
    return _toDomain(created);
  }

  Future<Party> updateParty(Party party) async {
    final updated = await _api.update(_toDto(party));
    return _toDomain(updated);
  }

  Party? findById(String id) {
    final dto = _api.findById(id);
    return dto == null ? null : _toDomain(dto);
  }

  Future<List<String>> getPartyTypes() => _api.partyTypes();

  Party _toDomain(PartyDto dto) => Party(
        id: dto.id,
        name: dto.name,
        address: dto.address,
        ownerName: dto.ownerName,
        panVat: dto.panVat,
        phone: dto.phone,
        email: dto.email,
        dateJoined: dto.dateJoined,
        partyType: dto.partyType,
        notes: dto.notes,
        latitude: dto.latitude,
        longitude: dto.longitude,
        imagePaths: dto.imagePaths,
      );

  PartyDto _toDto(Party p) => PartyDto(
        // Server assigns the canonical id on create — placeholder here.
        id: p.id,
        name: p.name,
        address: p.address,
        ownerName: p.ownerName,
        panVat: p.panVat,
        phone: p.phone,
        email: p.email,
        dateJoined: p.dateJoined,
        partyType: p.partyType,
        notes: p.notes,
        latitude: p.latitude,
        longitude: p.longitude,
        imagePaths: p.imagePaths,
      );
}

final partiesRepositoryProvider = Provider<PartiesRepository>((ref) {
  return PartiesRepository(api: ref.watch(partiesApiProvider));
});

/// Convenience provider for screens that just need the current list.
final partiesListProvider = FutureProvider<List<Party>>((ref) async {
  return ref.watch(partiesRepositoryProvider).getParties();
});

/// Resolves a single party by id from the in-memory store. Watches the list
/// provider so it rebuilds whenever the list changes (add / update).
final partyByIdProvider = Provider.family<Party?, String>((ref, id) {
  // Touch the list so rebuilds propagate when entries are added or updated.
  ref.watch(partiesListProvider);
  return ref.watch(partiesRepositoryProvider).findById(id);
});

/// Catalogue of party types used by the picker. Backed by a mock list in
/// the API today — swap to a real fetch when the backend ships it.
final partyTypesProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(partiesRepositoryProvider).getPartyTypes();
});
