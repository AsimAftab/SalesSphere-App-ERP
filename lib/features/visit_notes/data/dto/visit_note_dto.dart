/// Wire DTO for a visit-note row. Hand-written placeholder until the
/// backend publishes the visit-notes endpoint and `tool/gen_dto.sh`
/// can generate this.
class VisitNoteDto {
  const VisitNoteDto({
    required this.id,
    required this.title,
    required this.linkType,
    required this.linkId,
    required this.linkDisplayName,
    required this.description,
    required this.createdAt,
    this.imagePaths = const <String>[],
  });

  factory VisitNoteDto.fromJson(Map<String, dynamic> json) => VisitNoteDto(
        id: json['id'] as String,
        title: json['title'] as String,
        linkType: json['linkType'] as String,
        linkId: json['linkId'] as String,
        linkDisplayName: json['linkDisplayName'] as String,
        description: json['description'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        imagePaths: (json['imagePaths'] as List<dynamic>?)
                ?.cast<String>()
                .toList(growable: false) ??
            const <String>[],
      );

  final String id;
  final String title;

  /// `'party' | 'prospect' | 'site'` on the wire — kept as a String
  /// to match what the backend will send. The repo translates to the
  /// `VisitNoteLinkType` enum at the domain boundary.
  final String linkType;
  final String linkId;
  final String linkDisplayName;

  final String description;
  final DateTime createdAt;
  final List<String> imagePaths;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'linkType': linkType,
        'linkId': linkId,
        'linkDisplayName': linkDisplayName,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        if (imagePaths.isNotEmpty) 'imagePaths': imagePaths,
      };
}
