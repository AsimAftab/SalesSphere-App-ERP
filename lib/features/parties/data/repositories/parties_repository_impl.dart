import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/parties/data/dto/party_dto.dart';
import 'package:sales_sphere_erp/features/parties/data/parties_api.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/domain/repositories/parties_repository.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO ↔ domain mapping happens here. Drift persistence + outbox
/// enqueue will land alongside the real API.
class PartiesRepositoryImpl implements PartiesRepository {
  PartiesRepositoryImpl({required PartiesApi api}) : _api = api;

  final PartiesApi _api;

  @override
  Future<List<Party>> getParties() async {
    final dtos = await _api.list();
    return dtos.map(_toDomain).toList(growable: false);
  }

  @override
  Future<Party> addParty(Party draft) async {
    final created = await _api.create(_toDto(draft));
    return _toDomain(created);
  }

  @override
  Future<Party> updateParty(Party party) async {
    final updated = await _api.update(_toDto(party));
    return _toDomain(updated);
  }

  @override
  Future<List<String>> getPartyTypes() => _api.partyTypes();

  Party _toDomain(PartyDto dto) => Party(
        id: dto.id,
        name: dto.name,
        address: dto.address,
        // DTOs stay nullable for wire compatibility; the domain marks
        // owner + phone + panVat non-null because the form's validators
        // require them. Legacy / seed records without these surface as
        // empty strings and the form forces the user to fill them on
        // save.
        ownerName: dto.ownerName ?? '',
        panVat: dto.panVat ?? '',
        phone: dto.phone ?? '',
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

/// Exposes the abstract type so consumers depend on the contract, not the
/// impl class. Tests override this provider with a fake `PartiesRepository`.
final partiesRepositoryProvider = Provider<PartiesRepository>((ref) {
  return PartiesRepositoryImpl(api: ref.watch(partiesApiProvider));
});
