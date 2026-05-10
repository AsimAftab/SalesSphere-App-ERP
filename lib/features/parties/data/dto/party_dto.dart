/// Wire DTO for a Customer row from `GET /customers`. Hand-written until
/// `tool/gen_dto.sh` regenerates from `tool/openapi.json` — see
/// `customers.schemas.ts` (`CustomerDto`) on the backend for the source of
/// truth.
///
/// Naming asymmetries (translated here so callers don't learn both names):
///   * Wire `panNo` ↔ mobile `panVat` (form labels + validators).
///   * Wire `customerType: { id, name }` (read) / `customerType: "<name>"`
///     (write) ↔ mobile `partyType: String?`. We store only the name on
///     mobile; backend handles the FK lookup + auto-upsert on POST.
///
/// Slim by design — only the 13 fields the mobile UI actually consumes
/// today. Wider customer attributes (alias, country, ledger, images,
/// creditLimitAmount, …) are dropped from the wire model and added back
/// the day a screen needs them.
class PartyDto {
  const PartyDto({
    required this.id,
    required this.name,
    required this.status,
    this.address,
    this.ownerName,
    this.panNo,
    this.email,
    this.phone,
    this.notes,
    this.dateJoined,
    this.latitude,
    this.longitude,
    this.partyType,
  });

  factory PartyDto.fromJson(Map<String, dynamic> json) {
    final customerType = json['customerType'];
    final partyTypeName = customerType is Map<String, dynamic>
        ? customerType['name'] as String?
        : customerType is String
            ? customerType
            : null;
    return PartyDto(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      ownerName: json['ownerName'] as String?,
      panNo: json['panNo'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      dateJoined: (json['dateJoined'] as String?) != null
          ? DateTime.parse(json['dateJoined']! as String)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: (json['status'] as String?) ?? 'ACTIVE',
      partyType: partyTypeName,
    );
  }

  final String id;
  final String name;
  final String? address;
  final String? ownerName;
  final String? panNo;
  final String? email;
  final String? phone;
  final String? notes;
  final DateTime? dateJoined;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? partyType;

  /// Copy with a new id — used by the offline-write path in the repo to
  /// stamp a draft DTO with a local id (`local_<uuid>`) before drift
  /// upsert + outbox enqueue.
  PartyDto withId(String newId) => PartyDto(
        id: newId,
        name: name,
        status: status,
        address: address,
        ownerName: ownerName,
        panNo: panNo,
        email: email,
        phone: phone,
        notes: notes,
        dateJoined: dateJoined,
        latitude: latitude,
        longitude: longitude,
        partyType: partyType,
      );

  /// Writable subset for `POST /customers` and `PATCH /customers/{id}`.
  /// Server-assigned / read-only fields (`id`, `status`, `createdAt`,
  /// `organizationId`, …) are intentionally excluded. The backend
  /// auto-upserts `customerType` by name, so we send a flat string.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (address != null) 'address': address,
        if (ownerName != null) 'ownerName': ownerName,
        if (panNo != null) 'panNo': panNo,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (notes != null) 'notes': notes,
        if (dateJoined != null) 'dateJoined': dateJoined!.toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (partyType != null) 'customerType': partyType,
      };
}
