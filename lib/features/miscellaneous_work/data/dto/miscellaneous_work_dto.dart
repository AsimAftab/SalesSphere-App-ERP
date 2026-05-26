/// Wire DTO for a miscellaneous-work row, matching
/// `GET /miscellaneous-work`. Hand-written placeholder until the
/// backend lands in the OpenAPI spec and `tool/gen_dto.sh` can
/// generate this.
///
/// `images` carries the resolved Cloudinary URLs as returned by the
/// list endpoint — the add/edit pages use the same field for local
/// gallery picks before upload, so the repository layer treats them
/// uniformly until the upload endpoint is wired in.
class MiscellaneousWorkDto {
  const MiscellaneousWorkDto({
    required this.id,
    required this.natureOfWork,
    required this.assignedBy,
    required this.workDate,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.organizationId,
    this.employeeId,
    this.status,
    this.createdById,
    this.updatedAt,
    this.employee,
    this.createdBy,
    this.images = const <String>[],
  });

  factory MiscellaneousWorkDto.fromJson(Map<String, dynamic> json) =>
      MiscellaneousWorkDto(
        id: json['id'] as String,
        natureOfWork: json['natureOfWork'] as String,
        assignedBy: (json['assignedBy'] as String?) ?? '',
        workDate: DateTime.parse(json['workDate'] as String),
        address: (json['address'] as String?) ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        organizationId: json['organizationId'] as String?,
        employeeId: json['employeeId'] as String?,
        status: json['status'] as String?,
        createdById: json['createdById'] as String?,
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
        employee: json['employee'] == null
            ? null
            : MiscellaneousWorkUserDto.fromJson(
                json['employee'] as Map<String, dynamic>,
              ),
        createdBy: json['createdBy'] == null
            ? null
            : MiscellaneousWorkUserDto.fromJson(
                json['createdBy'] as Map<String, dynamic>,
              ),
        images: _readImages(json['images']),
      );

  /// The wire `images` array is shape-shifted across endpoints:
  ///   * `GET /miscellaneous-work` returns plain URL strings
  ///   * `GET /miscellaneous-work/{id}` and `PATCH` return full
  ///     image objects (`{ id, imageUrl, sortOrder, ... }`)
  ///
  /// Both flavours are normalised to a flat `List<String>` of URLs
  /// here so the list card render path stays simple. Slot-aware
  /// consumers (the edit page) read images through
  /// `MiscellaneousWorkImageRef` via the API's `listImages`.
  static List<String> _readImages(Object? raw) {
    if (raw is! List<dynamic>) return const <String>[];
    final out = <String>[];
    for (final entry in raw) {
      if (entry is String) {
        out.add(entry);
      } else if (entry is Map<String, dynamic>) {
        final url = entry['imageUrl'];
        if (url is String) out.add(url);
      }
    }
    return List<String>.unmodifiable(out);
  }

  final String id;
  final String natureOfWork;
  final String assignedBy;
  final DateTime workDate;

  final String address;
  final double latitude;
  final double longitude;

  final String? organizationId;
  final String? employeeId;
  final String? status;
  final String? createdById;
  final DateTime? updatedAt;

  final MiscellaneousWorkUserDto? employee;
  final MiscellaneousWorkUserDto? createdBy;

  final List<String> images;
  final DateTime createdAt;

  /// Writable subset for create/update bodies. Server assigns `id`,
  /// `createdAt`, `createdById`, `organizationId`, etc.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'natureOfWork': natureOfWork,
        'assignedBy': assignedBy,
        'workDate': workDate.toIso8601String(),
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };
}

/// Trimmed user reference embedded in the list response under
/// `employee` / `createdBy`. Same shape for both — only id/name/email
/// are returned by the list endpoint.
class MiscellaneousWorkUserDto {
  const MiscellaneousWorkUserDto({
    required this.id,
    required this.name,
    required this.email,
  });

  factory MiscellaneousWorkUserDto.fromJson(Map<String, dynamic> json) =>
      MiscellaneousWorkUserDto(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
      );

  final String id;
  final String name;
  final String email;
}
