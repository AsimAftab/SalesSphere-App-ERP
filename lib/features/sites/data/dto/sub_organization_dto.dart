/// Wire DTO for a sub-organization row. Hand-written placeholder
/// until the backend publishes the `/sub-organizations` endpoint and
/// `tool/gen_dto.sh` can generate this.
class SubOrganizationDto {
  const SubOrganizationDto({required this.id, required this.name});

  factory SubOrganizationDto.fromJson(Map<String, dynamic> json) =>
      SubOrganizationDto(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  final String id;
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
      };
}
