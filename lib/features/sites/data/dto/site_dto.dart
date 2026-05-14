/// Wire DTO for a site row from `GET /api/v1/sites` (and the matching
/// POST/PATCH endpoints). Hand-written until the backend's OpenAPI
/// spec is regenerated through `tool/gen_dto.sh` — see
/// `sites.schemas.ts` (`SiteDto`) on the backend for the source of
/// truth.
///
/// Wire shape notes (translated here so callers don't learn both names):
///   * `siteContacts` is an array of `[name, phone]` tuples on read AND
///     write, not `{name, phone}` objects.
///   * `interests` is grouped per category. On read: `[{ category:
///     {id, name}, brands: [...] }]`. On write: `[{ categoryName,
///     brands: [...] }]` (server resolves category by name and
///     auto-upserts the row). The mobile domain uses flat
///     `(category, brand)` pairs, so we flatten on parse and re-group
///     on serialise.
///   * `subOrganization` on read is a nested `{id, name}` block; on
///     write the body carries `subOrganizationName` and the server
///     resolves the id (auto-upserting if the name is new). We keep
///     both `subOrganizationId` and `subOrganizationName` on the DTO
///     so the round-trip is lossless.
///   * `dateJoined` is sent as a date-only string (`YYYY-MM-DD`) per
///     the POST contract. The server echoes it as ISO datetime on
///     read; parse handles both.
///   * `status` is server-managed; we don't send it on writes.
class SiteDto {
  const SiteDto({
    required this.id,
    required this.name,
    required this.address,
    this.ownerName,
    this.subOrganizationId,
    this.subOrganizationName,
    this.phone,
    this.email,
    this.description,
    this.dateJoined,
    this.interests = const <SiteInterestDto>[],
    this.contacts = const <SiteContactDto>[],
    this.notes,
    this.latitude,
    this.longitude,
    this.status = 'ACTIVE',
    this.imagePaths = const <String>[],
  });

  factory SiteDto.fromJson(Map<String, dynamic> json) {
    return SiteDto(
      id: json['id'] as String,
      name: json['name'] as String,
      address: (json['address'] as String?) ?? '',
      ownerName: json['ownerName'] as String?,
      subOrganizationId: json['subOrganizationId'] as String?,
      subOrganizationName: _subOrgName(json),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      description: json['description'] as String?,
      dateJoined: (json['dateJoined'] as String?) != null
          ? DateTime.parse(json['dateJoined']! as String)
          : null,
      interests: _parseInterests(json['interests']),
      contacts: _parseContacts(json['siteContacts'] ?? json['contacts']),
      notes: json['notes'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: (json['status'] as String?) ?? 'ACTIVE',
      // imagePaths aren't on the wire today — the gallery is local-only
      // until the `listImages` call hydrates the picker. Default empty
      // list from the constructor is correct.
    );
  }

  final String id;
  final String name;
  final String address;
  final String? ownerName;
  final String? subOrganizationId;
  final String? subOrganizationName;
  final String? phone;
  final String? email;
  final String? description;
  final DateTime? dateJoined;
  final List<SiteInterestDto> interests;
  final List<SiteContactDto> contacts;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final String status;
  final List<String> imagePaths;

  /// Writable subset for `POST /sites` and `PATCH /sites/{id}`. The
  /// server treats omitted fields as untouched and explicit nulls as
  /// a clear. Server-managed fields (`id`, `status`, `createdAt`,
  /// `organizationId`, …) are intentionally excluded.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'address': address,
        if (ownerName != null) 'ownerName': ownerName,
        if (subOrganizationName != null)
          'subOrganizationName': subOrganizationName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (description != null) 'description': description,
        if (dateJoined != null) 'dateJoined': _formatDateOnly(dateJoined!),
        if (interests.isNotEmpty) 'interests': _groupInterests(interests),
        if (contacts.isNotEmpty)
          'siteContacts':
              contacts.map((c) => <String>[c.name, c.phone]).toList(),
        if (notes != null) 'notes': notes,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  // ── Parsers ─────────────────────────────────────────────────────────────

  static String? _subOrgName(Map<String, dynamic> json) {
    final subOrg = json['subOrganization'];
    if (subOrg is Map<String, dynamic>) {
      return subOrg['name'] as String?;
    }
    // Fallback for shapes that send a flat `subOrganizationName` string
    // (the POST request body uses this, so an echo without the nested
    // object would still resolve cleanly).
    return json['subOrganizationName'] as String?;
  }

  static List<SiteInterestDto> _parseInterests(Object? raw) {
    if (raw is! List<dynamic>) return const <SiteInterestDto>[];
    final out = <SiteInterestDto>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final categoryName = _categoryName(entry);
      if (categoryName == null) continue;
      final brands = entry['brands'];
      if (brands is List<dynamic>) {
        for (final b in brands) {
          if (b is String && b.isNotEmpty) {
            out.add(SiteInterestDto(category: categoryName, brand: b));
          }
        }
      }
    }
    return List<SiteInterestDto>.unmodifiable(out);
  }

  static String? _categoryName(Map<String, dynamic> entry) {
    final category = entry['category'];
    if (category is Map<String, dynamic>) {
      return category['name'] as String?;
    }
    if (category is String) return category;
    // Echo shapes from the write side: the body uses `categoryName`
    // directly, so support that too.
    final flat = entry['categoryName'];
    if (flat is String) return flat;
    return null;
  }

  static List<SiteContactDto> _parseContacts(Object? raw) {
    if (raw is! List<dynamic>) return const <SiteContactDto>[];
    final out = <SiteContactDto>[];
    for (final entry in raw) {
      if (entry is List<dynamic> && entry.length >= 2) {
        final name = entry[0];
        final phone = entry[1];
        if (name is String && phone is String) {
          out.add(SiteContactDto(name: name, phone: phone));
        }
      } else if (entry is Map<String, dynamic>) {
        final name = entry['name'];
        final phone = entry['phone'];
        if (name is String && phone is String) {
          out.add(SiteContactDto(name: name, phone: phone));
        }
      }
    }
    return List<SiteContactDto>.unmodifiable(out);
  }

  /// Re-group flat `(category, brand)` pairs into the wire's per-category
  /// write shape: `[{ categoryName: '<name>', brands: [...] }]`.
  /// Preserves the first-seen order of categories and brands so
  /// write-then-read round-trips are stable.
  static List<Map<String, dynamic>> _groupInterests(
    List<SiteInterestDto> pairs,
  ) {
    final grouped = <String, List<String>>{};
    for (final p in pairs) {
      grouped.putIfAbsent(p.category, () => <String>[]).add(p.brand);
    }
    return grouped.entries
        .map(
          (e) => <String, dynamic>{'categoryName': e.key, 'brands': e.value},
        )
        .toList(growable: false);
  }

  /// Format a `DateTime` as a date-only string (`YYYY-MM-DD`) per the
  /// POST contract. The server normalises to UTC midnight on its end.
  static String _formatDateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

/// Wire-shape for a single category + brand interest entry. The
/// backend groups brands per category; this DTO stays flat so the
/// existing domain `Interest` (which is also flat) keeps a 1:1 mapping.
class SiteInterestDto {
  const SiteInterestDto({required this.category, required this.brand});

  final String category;
  final String brand;
}

/// Wire-shape for a secondary site contact (name + phone). On the
/// wire the row is a 2-element array (`[name, phone]`); we keep this
/// object for the mobile side so the picker / list code reads
/// naturally.
class SiteContactDto {
  const SiteContactDto({required this.name, required this.phone});

  final String name;
  final String phone;
}
