import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/sites/data/dto/site_dto.dart';
import 'package:sales_sphere_erp/features/sites/data/dto/sub_organization_dto.dart';

/// Raw data source for the sites endpoints. Currently backed by a
/// mutable in-memory list seeded from mock JSON — swap for Dio calls
/// once the sites endpoint lands in the backend OpenAPI spec.
/// Repository callers stay unchanged.
class SitesApi {
  SitesApi() {
    _store
      ..clear()
      ..addAll(_seed.map(SiteDto.fromJson));
  }

  /// In-memory category → brands catalogue backing the interest picker.
  /// Per-instance so additions made via [addInterestCategory] /
  /// [addInterestBrand] don't leak across `SitesApi` instances or
  /// between tests. Replaced by a real network fetch once the backend
  /// exposes a `/site-interests` endpoint.
  final Map<String, List<String>> _catalogue = <String, List<String>>{
    'Hardware': <String>['HP', 'Dell', 'Lenovo'],
    'Software': <String>['Microsoft', 'Adobe', 'JetBrains'],
    'Services': <String>['Consulting', 'Support'],
  };

  /// In-memory sub-organization (branch / division) catalogue powering
  /// the dropdown on the add/edit forms. Per-instance so test overrides
  /// stay clean. Swap to a real fetch once the backend exposes a
  /// `/sub-organizations` endpoint.
  final List<SubOrganizationDto> _subOrganizations = <SubOrganizationDto>[
    const SubOrganizationDto(id: 'so-hq', name: 'Headquarters'),
    const SubOrganizationDto(id: 'so-east', name: 'Eastern Region'),
    const SubOrganizationDto(id: 'so-west', name: 'Western Region'),
    const SubOrganizationDto(id: 'so-central', name: 'Central Region'),
  ];

  static final List<Map<String, dynamic>> _seed = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '1',
      'name': 'Acme Warehouse',
      'address': '4HP8+2RJ, Avalahalli',
      'ownerName': 'Anil Karki',
      'phone': '9801234567',
      'subOrganizationId': 'so-hq',
      'contacts': <Map<String, String>>[
        <String, String>{'name': 'Anita Sharma', 'phone': '9841234567'},
        <String, String>{'name': 'Ramesh Kulkarni', 'phone': '9821987654'},
      ],
    },
    <String, dynamic>{
      'id': '2',
      'name': 'Globex Branch',
      'address': 'F77F+CP7, Biratnagar',
      'ownerName': 'Sita Shrestha',
      'phone': '9812345678',
      'subOrganizationId': 'so-east',
    },
    <String, dynamic>{
      'id': '3',
      'name': 'Initech Office',
      'address': 'F77G+73R, Biratnagar',
      'ownerName': 'Ramesh Thapa',
      'phone': '9823456789',
      'subOrganizationId': 'so-east',
    },
  ];

  final List<SiteDto> _store = <SiteDto>[];

  Future<List<SiteDto>> list() async {
    // Simulated round-trip so callers exercise the loading state path.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List<SiteDto>.unmodifiable(_store);
  }

  Future<SiteDto> create(SiteDto draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final created = SiteDto(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: draft.name,
      address: draft.address,
      ownerName: draft.ownerName,
      subOrganizationId: draft.subOrganizationId,
      phone: draft.phone,
      email: draft.email,
      dateJoined: draft.dateJoined,
      interests: draft.interests,
      contacts: draft.contacts,
      notes: draft.notes,
      latitude: draft.latitude,
      longitude: draft.longitude,
      imagePaths: draft.imagePaths,
    );
    _store.add(created);
    return created;
  }

  Future<SiteDto> update(SiteDto site) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _store.indexWhere((s) => s.id == site.id);
    if (index == -1) {
      throw StateError('Site ${site.id} not found');
    }
    _store[index] = site;
    return site;
  }

  SiteDto? findById(String id) {
    for (final s in _store) {
      if (s.id == id) return s;
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

  Future<List<SubOrganizationDto>> subOrganizations() async {
    // Simulated round-trip so callers exercise the loading state path.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<SubOrganizationDto>.unmodifiable(_subOrganizations);
  }
}

final sitesApiProvider = Provider<SitesApi>((_) => SitesApi());
