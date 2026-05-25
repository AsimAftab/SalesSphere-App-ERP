/// Wire DTO for a note row, matching `GET /notes`. Hand-written
/// placeholder until the backend publishes the notes endpoint in the
/// OpenAPI spec and `tool/gen_dto.sh` can generate this.
///
/// The note is linked to exactly one of `customerId` / `prospectId` /
/// `siteId`; the other two are `null`. The repository collapses that
/// into `linkType + linkId` at the domain boundary.
class NoteDto {
  const NoteDto({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.customerId,
    this.prospectId,
    this.siteId,
    this.followUpDate,
    this.updatedAt,
    this.createdBy,
  });

  factory NoteDto.fromJson(Map<String, dynamic> json) => NoteDto(
    id: json['id'] as String,
    title: json['title'] as String,
    description: (json['description'] as String?) ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    customerId: json['customerId'] as String?,
    prospectId: json['prospectId'] as String?,
    siteId: json['siteId'] as String?,
    followUpDate: json['followUpDate'] == null
        ? null
        : DateTime.parse(json['followUpDate'] as String),
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.parse(json['updatedAt'] as String),
    createdBy: json['createdBy'] == null
        ? null
        : NoteCreatedByDto.fromJson(
            json['createdBy'] as Map<String, dynamic>,
          ),
  );

  final String id;
  final String title;
  final String description;
  final DateTime createdAt;

  final String? customerId;
  final String? prospectId;
  final String? siteId;

  final DateTime? followUpDate;
  final DateTime? updatedAt;
  final NoteCreatedByDto? createdBy;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    // Always emit the three link-id fields and followUpDate (even when
    // null) so the PATCH path can clear / switch them. The backend
    // treats explicit null as a clear and any omitted field as
    // unchanged; for create, accepting null on the inactive link
    // fields is fine — the backend's XOR check sees exactly one
    // populated id either way.
    'customerId': customerId,
    'prospectId': prospectId,
    'siteId': siteId,
    'followUpDate': followUpDate?.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (createdBy != null) 'createdBy': createdBy!.toJson(),
  };
}

class NoteCreatedByDto {
  const NoteCreatedByDto({
    required this.id,
    required this.name,
    required this.email,
  });

  factory NoteCreatedByDto.fromJson(Map<String, dynamic> json) =>
      NoteCreatedByDto(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
      );

  final String id;
  final String name;
  final String email;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'email': email,
  };
}
