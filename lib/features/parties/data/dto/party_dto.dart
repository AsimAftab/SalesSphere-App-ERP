/// Wire DTO for a party row. Hand-written placeholder until the backend
/// publishes the parties endpoint and `tool/gen_dto.sh` can generate this.
class PartyDto {
  const PartyDto({
    required this.id,
    required this.name,
    required this.address,
    this.ownerName,
    this.panVat,
    this.phone,
    this.email,
    this.dateJoined,
    this.partyType,
    this.notes,
    this.latitude,
    this.longitude,
    this.imagePaths = const <String>[],
  });

  factory PartyDto.fromJson(Map<String, dynamic> json) => PartyDto(
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
        partyType: json['partyType'] as String?,
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
  final String? partyType;
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
        if (partyType != null) 'partyType': partyType,
        if (notes != null) 'notes': notes,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (imagePaths.isNotEmpty) 'imagePaths': imagePaths,
      };
}
