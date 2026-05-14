/// Wire DTO for a sub-organization row from
/// `GET /api/v1/site-sub-organizations`. Extra wire fields
/// (`siteCount`, `createdAt`, `updatedAt`) are intentionally ignored
/// — the dropdown only consumes `id` + `name`.
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
