/// Wire DTO for a site row. Hand-written placeholder until the
/// backend publishes the sites endpoint and `tool/gen_dto.sh` can
/// generate this.
class SiteDto {
  const SiteDto({
    required this.id,
    required this.name,
    required this.address,
    this.ownerName,
    this.subOrganizationId,
    this.phone,
    this.email,
    this.dateJoined,
    this.interests = const <SiteInterestDto>[],
    this.notes,
    this.latitude,
    this.longitude,
    this.imagePaths = const <String>[],
  });

  factory SiteDto.fromJson(Map<String, dynamic> json) => SiteDto(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        ownerName: json['ownerName'] as String?,
        subOrganizationId: json['subOrganizationId'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        dateJoined: (json['dateJoined'] as String?) != null
            ? DateTime.parse(json['dateJoined']! as String)
            : null,
        interests: (json['interests'] as List<dynamic>?)
                ?.map((e) =>
                    SiteInterestDto.fromJson(e as Map<String, dynamic>))
                .toList(growable: false) ??
            const <SiteInterestDto>[],
        notes: json['notes'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        imagePaths: (json['imagePaths'] as List<dynamic>?)
                ?.cast<String>()
                .toList(growable: false) ??
            const <String>[],
      );

  final String id;
  final String name;
  final String address;
  final String? ownerName;
  final String? subOrganizationId;
  final String? phone;
  final String? email;
  final DateTime? dateJoined;
  final List<SiteInterestDto> interests;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final List<String> imagePaths;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'address': address,
        if (ownerName != null) 'ownerName': ownerName,
        if (subOrganizationId != null) 'subOrganizationId': subOrganizationId,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (dateJoined != null) 'dateJoined': dateJoined!.toIso8601String(),
        if (interests.isNotEmpty)
          'interests': interests.map((e) => e.toJson()).toList(),
        if (notes != null) 'notes': notes,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (imagePaths.isNotEmpty) 'imagePaths': imagePaths,
      };
}

/// Wire-shape for a single category + brand interest entry. Carries
/// its own optional list of (name, phone) contacts so the backend
/// stores the (category → contacts) link together with the brand pick.
class SiteInterestDto {
  const SiteInterestDto({
    required this.category,
    required this.brand,
    this.contacts = const <SiteContactDto>[],
  });

  factory SiteInterestDto.fromJson(Map<String, dynamic> json) =>
      SiteInterestDto(
        category: json['category'] as String,
        brand: json['brand'] as String,
        contacts: (json['contacts'] as List<dynamic>?)
                ?.map((e) =>
                    SiteContactDto.fromJson(e as Map<String, dynamic>))
                .toList(growable: false) ??
            const <SiteContactDto>[],
      );

  final String category;
  final String brand;
  final List<SiteContactDto> contacts;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'category': category,
        'brand': brand,
        if (contacts.isNotEmpty)
          'contacts': contacts.map((e) => e.toJson()).toList(),
      };
}

/// Wire-shape for a single site contact (name + phone). Mirrors the
/// fields the future backend will return.
class SiteContactDto {
  const SiteContactDto({required this.name, required this.phone});

  factory SiteContactDto.fromJson(Map<String, dynamic> json) =>
      SiteContactDto(
        name: json['name'] as String,
        phone: json['phone'] as String,
      );

  final String name;
  final String phone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'phone': phone,
      };
}
