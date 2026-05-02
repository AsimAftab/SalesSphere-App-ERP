import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/prospects/data/dto/prospect_dto.dart';

/// Raw data source for the prospects endpoints. Currently backed by a
/// mutable in-memory list seeded from mock JSON — swap for Dio calls
/// once the prospects endpoint lands in the backend OpenAPI spec.
/// Repository callers stay unchanged.
class ProspectsApi {
  ProspectsApi() {
    _store
      ..clear()
      ..addAll(_seed.map(ProspectDto.fromJson));
  }

  /// In-memory category → brands catalogue backing the interest picker.
  /// Replaced by a real network fetch once the backend exposes a
  /// `/prospect-interests` endpoint.
  static final Map<String, List<String>> _catalogue = <String, List<String>>{
    'Hardware': <String>['HP', 'Dell', 'Lenovo'],
    'Software': <String>['Microsoft', 'Adobe', 'JetBrains'],
    'Services': <String>['Consulting', 'Support'],
  };

  static final List<Map<String, dynamic>> _seed = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '1',
      'name': 'Acme Corp',
      'address': '4HP8+2RJ, Avalahalli',
    },
    <String, dynamic>{
      'id': '2',
      'name': 'Globex',
      'address': 'F77F+CP7, Biratnagar',
    },
    <String, dynamic>{
      'id': '3',
      'name': 'Initech',
      'address': 'F77G+73R, Biratnagar',
    },
  ];

  final List<ProspectDto> _store = <ProspectDto>[];

  Future<List<ProspectDto>> list() async {
    // Simulated round-trip so callers exercise the loading state path.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List<ProspectDto>.unmodifiable(_store);
  }

  Future<ProspectDto> create(ProspectDto draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final created = ProspectDto(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: draft.name,
      address: draft.address,
      ownerName: draft.ownerName,
      panVat: draft.panVat,
      phone: draft.phone,
      email: draft.email,
      dateJoined: draft.dateJoined,
      interests: draft.interests,
      notes: draft.notes,
      latitude: draft.latitude,
      longitude: draft.longitude,
      imagePaths: draft.imagePaths,
    );
    _store.add(created);
    return created;
  }

  Future<ProspectDto> update(ProspectDto prospect) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _store.indexWhere((p) => p.id == prospect.id);
    if (index == -1) {
      throw StateError('Prospect ${prospect.id} not found');
    }
    _store[index] = prospect;
    return prospect;
  }

  ProspectDto? findById(String id) {
    for (final p in _store) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<Map<String, List<String>>> interestCatalogue() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Defensive deep-copy so callers can't mutate the store directly.
    return <String, List<String>>{
      for (final entry in _catalogue.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    };
  }

  Future<void> addInterestCategory(String category) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _catalogue.putIfAbsent(category, () => <String>[]);
  }

  Future<void> addInterestBrand(String category, String brand) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final list = _catalogue.putIfAbsent(category, () => <String>[]);
    if (!list.contains(brand)) list.add(brand);
  }
}

final prospectsApiProvider = Provider<ProspectsApi>((_) => ProspectsApi());
