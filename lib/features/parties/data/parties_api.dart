import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/parties/data/dto/party_dto.dart';

/// Raw data source for the parties endpoints. Currently backed by a mutable
/// in-memory list seeded from mock JSON — swap for Dio calls once the
/// parties endpoint lands in the backend OpenAPI spec. Repository callers
/// stay unchanged.
class PartiesApi {
  PartiesApi() {
    _store
      ..clear()
      ..addAll(_seed.map(PartyDto.fromJson));
  }

  /// In-memory party-type catalog backing [partyTypes]. Replaced by a real
/// network fetch once the backend exposes a `/party-types` endpoint.
  static final List<String> _typeStore = <String>[
    'Customer',
    'Vendor',
    'Distributor',
    'Retailer',
    'Hardware',
  ];

  static final List<Map<String, dynamic>> _seed = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '1',
      'name': 'ejejej',
      'address': '4HP8+2RJ, Avalahalli',
    },
    <String, dynamic>{
      'id': '2',
      'name': 'what',
      'address': 'F77F+CP7, Biratnagar',
    },
    <String, dynamic>{
      'id': '3',
      'name': 'aa',
      'address': 'F77G+73R, Biratnagar',
    },
  ];

  final List<PartyDto> _store = <PartyDto>[];

  Future<List<PartyDto>> list() async {
    // Simulated round-trip so callers exercise the loading state path.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List<PartyDto>.unmodifiable(_store);
  }

  Future<PartyDto> create(PartyDto draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final created = PartyDto(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: draft.name,
      address: draft.address,
      ownerName: draft.ownerName,
      panVat: draft.panVat,
      phone: draft.phone,
      email: draft.email,
      dateJoined: draft.dateJoined,
      partyType: draft.partyType,
      notes: draft.notes,
      latitude: draft.latitude,
      longitude: draft.longitude,
      imagePaths: draft.imagePaths,
    );
    _store.add(created);
    return created;
  }

  Future<PartyDto> update(PartyDto party) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _store.indexWhere((p) => p.id == party.id);
    if (index == -1) {
      throw StateError('Party ${party.id} not found');
    }
    _store[index] = party;
    return party;
  }

  PartyDto? findById(String id) {
    for (final p in _store) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<List<String>> partyTypes() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<String>.unmodifiable(_typeStore);
  }
}

final partiesApiProvider = Provider<PartiesApi>((_) => PartiesApi());
