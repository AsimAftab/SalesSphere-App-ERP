/// Wire DTO for a prospect row from `GET /prospects`. Hand-written until
/// `tool/gen_dto.sh` regenerates from `tool/openapi.json` — see
/// `prospects.schemas.ts` (`ProspectDto`) on the backend for the source
/// of truth.
///
/// Naming asymmetries (translated here so callers don't learn both names):
///   * Wire `panNo` ↔ mobile `panVat`.
///   * Wire `description` ↔ mobile `notes`.
///   * Wire `interests[].category.name` + `interests[].brands[]` ↔ mobile
///     flat `(category, brand)` pairs. A category with multiple brands
///     fans out to multiple `ProspectInterestDto`s; an empty `brands`
///     list keeps a single entry with `brand = ''` so the category is
///     still surfaced in the picker.
class ProspectDto {
  const ProspectDto({
    required this.id,
    required this.name,
    this.address,
    this.ownerName,
    this.panVat,
    this.phone,
    this.email,
    this.dateJoined,
    this.interests = const <ProspectInterestDto>[],
    this.notes,
    this.latitude,
    this.longitude,
    this.imagePaths = const <String>[],
  });

  factory ProspectDto.fromJson(Map<String, dynamic> json) {
    final rawInterests = json['interests'];
    final interests = <ProspectInterestDto>[];
    if (rawInterests is List<dynamic>) {
      for (final entry in rawInterests) {
        if (entry is! Map<String, dynamic>) continue;
        final category = entry['category'];
        final categoryName = category is Map<String, dynamic>
            ? category['name'] as String?
            : entry['category'] as String?;
        if (categoryName == null || categoryName.isEmpty) continue;
        final brands = (entry['brands'] as List<dynamic>?)
                ?.cast<String>()
                .toList(growable: false) ??
            const <String>[];
        if (brands.isEmpty) {
          interests.add(
            ProspectInterestDto(category: categoryName, brand: ''),
          );
        } else {
          for (final brand in brands) {
            interests.add(
              ProspectInterestDto(category: categoryName, brand: brand),
            );
          }
        }
      }
    }

    return ProspectDto(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      ownerName: json['ownerName'] as String?,
      panVat: json['panNo'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      dateJoined: (json['dateJoined'] as String?) != null
          ? DateTime.parse(json['dateJoined']! as String)
          : null,
      interests: List<ProspectInterestDto>.unmodifiable(interests),
      notes: (json['description'] as String?) ?? json['notes'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imagePaths: (json['imagePaths'] as List<dynamic>?)
              ?.cast<String>()
              .toList(growable: false) ??
          const <String>[],
    );
  }

  final String id;
  final String name;
  final String? address;
  final String? ownerName;
  final String? panVat;
  final String? phone;
  final String? email;
  final DateTime? dateJoined;
  final List<ProspectInterestDto> interests;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final List<String> imagePaths;

  /// Writable subset for `POST /prospects` and `PATCH /prospects/{id}`.
  /// Server-assigned / read-only fields are excluded. Interests are
  /// re-grouped into `{ categoryName, brands[] }` form to match the
  /// wire contract — pairs sharing a category collapse into a single
  /// entry. Note the asymmetry: the response shape uses
  /// `category: { id, name }`, but the request body wants the flat
  /// `categoryName` so the backend can upsert by name.
  ///
  /// `dateJoined` is sent as `yyyy-MM-dd` (date-only) per the spec —
  /// `toIso8601String()` would emit a timestamp the server rejects.
  /// `imagePaths` are deliberately dropped: image upload is a separate
  /// multipart endpoint, not part of the JSON body.
  Map<String, dynamic> toJson() {
    final grouped = <String, List<String>>{};
    for (final i in interests) {
      final list = grouped.putIfAbsent(i.category, () => <String>[]);
      if (i.brand.isNotEmpty && !list.contains(i.brand)) list.add(i.brand);
    }
    return <String, dynamic>{
      'name': name,
      if (address != null) 'address': address,
      if (ownerName != null) 'ownerName': ownerName,
      if (panVat != null) 'panNo': panVat,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (dateJoined != null)
        'dateJoined': dateJoined!.toIso8601String().substring(0, 10),
      if (grouped.isNotEmpty)
        'interests': grouped.entries
            .map((e) => <String, dynamic>{
                  'categoryName': e.key,
                  'brands': e.value,
                })
            .toList(),
      if (notes != null) 'description': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}

/// Flattened `(category, brand)` pair surfaced to the domain layer.
/// A wire interest with N brands maps to N of these; a wire interest
/// with empty `brands` keeps a single entry with `brand = ''`.
class ProspectInterestDto {
  const ProspectInterestDto({required this.category, required this.brand});

  final String category;
  final String brand;
}
