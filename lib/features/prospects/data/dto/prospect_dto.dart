/// Wire DTO for a prospect row. Hand-written placeholder until the
/// backend publishes the prospects endpoint and `tool/gen_dto.sh` can
/// generate this.
class ProspectDto {
  const ProspectDto({
    required this.id,
    required this.name,
    required this.address,
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

  factory ProspectDto.fromJson(Map<String, dynamic> json) => ProspectDto(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        ownerName: json['ownerName'] as String?,
        panVat: json['panVat'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        dateJoined: (json['dateJoined'] as String?) != null
            ? DateTime.parse(json['dateJoined']! as String)
            : null,
        interests: (json['interests'] as List<dynamic>?)
                ?.map((e) =>
                    ProspectInterestDto.fromJson(e as Map<String, dynamic>))
                .toList(growable: false) ??
            const <ProspectInterestDto>[],
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
  final String? panVat;
  final String? phone;
  final String? email;
  final DateTime? dateJoined;
  final List<ProspectInterestDto> interests;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final List<String> imagePaths;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'address': address,
        if (ownerName != null) 'ownerName': ownerName,
        if (panVat != null) 'panVat': panVat,
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

/// Wire-shape for a single category + brand interest entry. Mirrors the
/// fields the future backend will return.
class ProspectInterestDto {
  const ProspectInterestDto({required this.category, required this.brand});

  factory ProspectInterestDto.fromJson(Map<String, dynamic> json) =>
      ProspectInterestDto(
        category: json['category'] as String,
        brand: json['brand'] as String,
      );

  final String category;
  final String brand;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'category': category,
        'brand': brand,
      };
}
