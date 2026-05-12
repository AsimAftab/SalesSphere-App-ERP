/// What kind of entity a note is linked to. Exactly one of
/// these is set on every note (the "linked to one party / prospect /
/// site" requirement from the form).
enum NoteLinkType { party, prospect, site }

/// UI-facing note model. Decoupled from wire DTOs so backend
/// renames don't ripple into widgets. Will be promoted to freezed
/// once the notes API + drift table land.
///
/// Linked entity is denormalised — the note stores
/// `linkType + linkId + linkDisplayName` so the list page can render
/// without doing N cross-feature lookups per frame. The display name
/// can drift if the linked entity is renamed; for the in-memory MVP
/// that's acceptable.
class Note {
  const Note({
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

  final String id;
  final String title;

  final NoteLinkType linkType;
  final String linkId;
  final String linkDisplayName;

  final String description;
  final DateTime createdAt;

  /// Up to two attached image paths (gallery picks). Empty when none
  /// have been added.
  final List<String> imagePaths;

  /// When the user plans to revisit the linked entity. Optional —
  /// older notes won't have one. Derived dashboards (e.g. "Follow-ups
  /// this week") read this field.
  final DateTime? nextFollowUpAt;
}
