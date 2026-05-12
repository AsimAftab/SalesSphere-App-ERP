/// Wire DTO for a note row. Hand-written placeholder until the
/// backend publishes the notes endpoint and `tool/gen_dto.sh`
/// can generate this.
class NoteDto {
  const NoteDto({
    required this.id,
    required this.title,
    required this.linkType,
    required this.linkId,
    required this.linkDisplayName,
    required this.description,
    required this.createdAt,
    this.imagePaths = const <String>[],
    this.nextFollowUpAt,
  });

  factory NoteDto.fromJson(Map<String, dynamic> json) => NoteDto(
    id: json['id'] as String,
    title: json['title'] as String,
    linkType: json['linkType'] as String,
    linkId: json['linkId'] as String,
    linkDisplayName: json['linkDisplayName'] as String,
    description: json['description'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    imagePaths:
        (json['imagePaths'] as List<dynamic>?)?.cast<String>().toList(
          growable: false,
        ) ??
        const <String>[],
    nextFollowUpAt: json['nextFollowUpAt'] == null
        ? null
        : DateTime.parse(json['nextFollowUpAt'] as String),
  );

  final String id;
  final String title;

  /// `'party' | 'prospect' | 'site'` on the wire — kept as a String
  /// to match what the backend will send. The repo translates to the
  /// `NoteLinkType` enum at the domain boundary.
  final String linkType;
  final String linkId;
  final String linkDisplayName;

  final String description;
  final DateTime createdAt;
  final List<String> imagePaths;

  /// Optional planned follow-up date for the linked entity. Omitted
  /// from `toJson` when null so the backend receives `null`/absence
  /// uniformly rather than the string `"null"`.
  final DateTime? nextFollowUpAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'linkType': linkType,
    'linkId': linkId,
    'linkDisplayName': linkDisplayName,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    if (imagePaths.isNotEmpty) 'imagePaths': imagePaths,
    if (nextFollowUpAt != null)
      'nextFollowUpAt': nextFollowUpAt!.toIso8601String(),
  };
}
